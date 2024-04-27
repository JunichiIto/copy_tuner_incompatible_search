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
            line.scan(/['"](\.[^'"]+)/).flatten.each do |lazy_key|
              @usages << Usage.new(line, lazy_key)
            end
          else
            @usages << Usage.new(line)
          end
        end
      end
    end

    class Usage
      attr_reader :file, :line, :code, :lazy_key

      def initialize(grep_result, lazy_key = nil)
        file, line, code = grep_result.split(':', 3)
        @file = file
        @line = line
        @code = code.strip
        @lazy_key = lazy_key
      end
    end

    def search_incompatible_keys
      stdout = detect_html_incompatible_keys
      keys = stdout.lines(chomp: true).map do |line|
        line.split('.', 2).last
      end.uniq.sort
      Set[*keys]
    end

    def search_static_usages(incompatible_keys)
      puts "Searching #{incompatible_keys.count} keys"
      count = 0
      incompatible_keys.map do |key|
        count += 1
        puts "#{count} / #{incompatible_keys.count}" if (count % 100).zero?

        result = Result.new(:static, key)
        usage = grep_usage(key).strip
        unless usage.empty?
          result.add_usage(usage)
        end
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
