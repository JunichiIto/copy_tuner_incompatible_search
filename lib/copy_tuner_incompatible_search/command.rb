# frozen_string_literal: true

require 'axlsx'
require 'set'

module CopyTunerIncompatibleSearch
  class Command
    def self.run(output_path)
      self.new.run(output_path)
    end

    def run(output_path)
      puts 'Start'
      incompatible_keys = search_incompatible_keys
      results = search_static_usages(incompatible_keys)
      results << search_lazy_usages
      results << search_dynamic_usages
      ignored_keys = search_ignored_keys
      XlsxWriter.save_to(results, incompatible_keys, ignored_keys, output_path)
      puts 'Finish'
    end

    private

    class Result
      attr_reader :type, :key, :usages

      def initialize(type, key)
        @type = type
        @key = key
        @usages = []
      end

      def static?
        @type == :static
      end

      def lazy?
        @type == :lazy
      end

      def dynamic?
        @type == :dynamic
      end

      def add_usage(grep_result)
        grep_result.each_line do |line|
          if lazy?
            line.scan(/(?<=['"])\.[^'"]+/) do |lazy_key|
              @usages << Usage.new(line, lazy_key.to_s)
            end
          else
            @usages << Usage.new(line)
          end
        end
      end

      def full_key_for(usage)
        if lazy?
          path = usage
                 .file
                 .sub(%r{^app/views/}, '')
                 .sub(/\..+$/, '')
                 .sub('/_', '/')
                 .gsub('/', '.')
          path + usage.lazy_key.to_s
        else
          key
        end
      end

      def already_migrated?(usage)
        used_key = lazy? ? usage.lazy_key : key
        usage.initializers? || usage.code.include?("#{used_key}_html")
      end
    end

    class Usage
      attr_reader :file, :line, :code, :lazy_key

      def initialize(grep_result, lazy_key = nil)
        file, line, code = grep_result.split(':', 3)
        @file = file
        @line = line
        @code = code.to_s.strip
        @lazy_key = lazy_key
      end

      def initializers?
        file == 'config/initializers/copy_tuner.rb'
      end
    end

    def search_incompatible_keys
      stdout = detect_html_incompatible_keys
      keys = stdout.lines(chomp: true).map do |line|
        line.split('.', 2).last.to_s
      end.uniq.sort
      Set[*keys]
    end

    def search_static_usages(incompatible_keys)
      puts "Searching #{incompatible_keys.count} keys"
      incompatible_keys.map.with_index(1) do |key, count|
        puts "#{count} / #{incompatible_keys.count}" if (count % 100).zero?

        result = Result.new(:static, key)
        usage = grep_usage(key).strip
        result.add_usage(usage)
        result
      end
    end

    def search_lazy_usages
      grep_result = grep_lazy_keys
      result = Result.new(:lazy, '')
      result.add_usage(grep_result)
      result
    end

    def search_dynamic_usages
      grep_result = grep_dynamic_keys
      result = Result.new(:dynamic, '')
      result.add_usage(grep_result)
      result
    end

    def search_ignored_keys
      Set[*eval(ignored_keys_text)] # rubocop:disable Security/Eval
    end

    def detect_html_incompatible_keys
      `rails copy_tuner:detect_html_incompatible_keys`
    end

    def grep_lazy_keys
      `git grep -n -P "\\btt?[ \\(]['\\"]\\.\\w+"`
    end

    def grep_dynamic_keys
      `git grep -n -P "\\btt?[ \\(]['\\"][\\w.-]*[#$]"`
    end

    def grep_usage(key)
      `git grep -n "#{Regexp.escape(key)}"`
    end

    def ignored_keys_text
      `rails r "p CopyTunerClient::configuration.ignored_keys"`
    end
  end
end
