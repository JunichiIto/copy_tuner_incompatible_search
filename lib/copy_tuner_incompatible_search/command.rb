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

      stdout = detect_html_incompatible_keys
      keys = stdout.lines(chomp: true).map do |line|
        line.split('.', 2).last
      end.uniq.sort
      keys = Set[*keys]

      results = []

      # 完全一致する翻訳キー
      puts "Searching #{keys.count} keys"
      count = 0
      keys.each do |key|
        count += 1
        puts "#{count} / #{keys.count}" if (count % 100).zero?

        result = Result.new(:static, key)
        usage = grep_usage(key).strip
        unless usage.empty?
          result.add_usage(usage)
        end
        results << result
      end

      # .で始まる翻訳キー
      grep_result = grep_lazy_keys
      result = Result.new(:lazy, '')
      result.add_usage(grep_result)
      results << result

      # 変数を含む翻訳キー
      grep_result = grep_dynamic_keys
      result = Result.new(:dynamic, '')
      result.add_usage(grep_result)
      results << result

      # Excelに出力
      dump_to_xlsx(results, keys, output_path)

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

    def ignored_keys
      @ignored_keys ||= Set[*eval(ignored_keys_text)]
    end

    def ignored_keys_text
      `rails r "p CopyTunerClient::configuration.ignored_keys"`
    end

    def dump_to_xlsx(results, keys, output_path)
      Axlsx::Package.new do |p|
        p.workbook.add_worksheet(name: 'Data') do |sheet|
          monospace_style = sheet.styles.add_style(font_name: 'Courier New', sz: 14)
          sheet.add_row %w[Type Key Ignored File Line Code], style: monospace_style
          sheet.auto_filter = 'A1:F1'

          # freeze pane
          sheet.sheet_view.pane do |pane|
            pane.top_left_cell = 'A2'
            pane.state = :frozen_split
            pane.y_split = 1
            pane.x_split = 0
            pane.active_pane = :bottom_right
          end

          results.each do |result|
            added = false
            result.usages.each do |usage|
              key = if result.lazy?
                      path = usage.file.sub(%r{^app/views/}, '').sub(/\..+$/, '').sub('/_', '/').gsub('/', '.')
                      path + usage.lazy_key
                    else
                      result.key
                    end
              already_migrated = usage.file == 'config/initializers/copy_tuner.rb' || usage.code.include?("#{usage.lazy_key || result.key}_html")
              next unless (!result.lazy? || keys.include?(key)) && !already_migrated

              ignored = unless result.dynamic? then ignored_keys.include?(key) ? 'Y' : 'N' end
              sheet.add_row [result.type, key, ignored.to_s, usage.file, usage.line, usage.code], style: monospace_style
              added = true
            end
            if !added && result.static?
              ignored = ignored_keys.include?(result.key) ? 'Y' : 'N'
              sheet.add_row [result.type, result.key, ignored.to_s, '', '', ''], style: monospace_style
            end
          end
        end
        p.serialize(output_path)
      end
    end
  end
end
