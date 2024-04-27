# frozen_string_literal: true

require 'set'

module CopyTunerIncompatibleSearch
  class Command
    def self.run
      self.new.run
    end

    def main
      puts "Start"

      stdout = `rails copy_tuner:detect_html_incompatible_keys`
      keys = stdout.lines(chomp: true).map do |line|
        line.split(".", 2).last
      end.uniq.sort
      keys = Set[*keys]

      # 完全一致する翻訳キー
      puts "Searching #{keys.count} keys"
      count = 0
      results = {}
      keys.each do |key|
        count += 1
        puts "#{count} / #{keys.count}" if count % 100 == 0

        results[key] ||= Result.new(:static, key)
        result = `git grep -n "#{Regexp.escape(key)}"`.strip
        unless result.empty?
          results[key].add_usage(result)
        end
      end

      # .で始まる翻訳キー
      grep_result = `git grep -n -P "\\btt?[ \\(]['\\"]\\.\\w+"`
      results['lazy'] = Result.new(:lazy, "")
      results['lazy'].add_usage(grep_result)

      # 変数を含む翻訳キー
      grep_result = `git grep -n -P "\\btt?[ \\(]['\\"][\\w.-]*[#$]"`
      results['with vars'] = Result.new(:dynamic, "")
      results['with vars'].add_usage(grep_result)

      # Excelに出力
      project_name = File.basename(Dir.pwd)
      timestamp = Time.now.strftime("%Y%m%d%H%M%S")
      output_path = "tmp/usages-#{project_name}-#{timestamp}.xlsx"
      dump_to_xlsx(results, keys, output_path)

      puts "Finish"
      puts "open #{output_path}"
      `open #{output_path}`
    end

    private

    class Result
      attr_reader :type, :key, :usages

      def initialize(type, key)
        @type = type
        @key = key
        @usages = []
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
        file, line, code = grep_result.split(":", 3)
        @file = file
        @line = line
        @code = code.strip
        @lazy_key = lazy_key
      end
    end

    def ignored_keys
      @ignored_keys ||= begin
                          text = `rails r "p CopyTunerClient::configuration.ignored_keys"`
                          Set[*eval(text)]
                        end
    end

    def dump_to_xlsx(results, keys, output_path)
      Axlsx::Package.new do |p|
        p.workbook.add_worksheet(name: "Data") do |sheet|
          monospace_style = sheet.styles.add_style(font_name: 'Courier New', sz: 14)
          sheet.add_row ["Type", "Key", "Ignored", "File", "Line", "Code"], style: monospace_style
          sheet.auto_filter = "A1:F1"

          # freeze pane
          sheet.sheet_view.pane do |pane|
            pane.top_left_cell = 'A2'
            pane.state = :frozen_split
            pane.y_split = 1
            pane.x_split = 0
            pane.active_pane = :bottom_right
          end

          results.each do |key, result|
            added = false
            result.usages.each do |usage|
              key = if result.lazy?
                      path = usage.file.sub(/^app\/views\//, '').sub(/\..+$/, '').sub('/_', '/').gsub('/', '.')
                      path + usage.lazy_key
                    else
                      result.key
                    end
              already_migrated = usage.file == 'config/initializers/copy_tuner.rb' || usage.code.include?("#{usage.lazy_key || result.key}_html")
              if (!result.lazy? || keys.include?(key)) && !already_migrated
                ignored = unless result.dynamic? then ignored_keys.include?(key) ? "Y" : "N" end
                sheet.add_row [result.type, key, ignored.to_s, usage.file, usage.line, usage.code], style: monospace_style
                added = true
              end
            end
            if !added && !result.lazy?
              ignored = ignored_keys.include?(result.key) ? "Y" : "N"
              sheet.add_row [result.type, result.key, ignored.to_s, "", "", ""], style: monospace_style
            end
          end
        end
        p.serialize(output_path)
      end
    end
  end
end
