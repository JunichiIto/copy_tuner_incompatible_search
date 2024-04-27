# frozen_string_literal: true

module CopyTunerIncompatibleSearch
  class XlsxWriter
    def self.dump_to_xlsx(results, incompatible_keys, ignored_keys, output_path)
      self.new(results, incompatible_keys, ignored_keys).dump_to_xlsx(output_path)
    end

    def initialize(results, incompatible_keys, ignored_keys)
      @results = results
      @incompatible_keys = incompatible_keys
      @ignored_keys = ignored_keys
    end

    def dump_to_xlsx(output_path)
      Axlsx::Package.new do |p|
        p.workbook.add_worksheet(name: 'Data') do |sheet|
          style = sheet.styles.add_style(font_name: 'Courier New', sz: 14)
          sheet.add_row %w[Type Key Ignored File Line Code], style: style
          sheet.auto_filter = 'A1:F1'
          freeze_pane(sheet)

          results.each do |result|
            add_result_rows(sheet, result, style)
          end
        end
        p.serialize(output_path)
      end
    end

    private

    attr_reader :results, :incompatible_keys, :ignored_keys

    def freeze_pane(sheet)
      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = 'A2'
        pane.state = :frozen_split
        pane.y_split = 1
        pane.x_split = 0
        pane.active_pane = :bottom_right
      end
    end

    def add_result_rows(sheet, result, style)
      added = false
      result.usages.each do |usage|
        key = build_key(result, usage)
        next unless should_output?(usage, result, key)

        ignored = ignored_flag(key) unless result.dynamic?
        sheet.add_row [result.type, key, ignored.to_s, usage.file, usage.line, usage.code], style: style
        added = true
      end
      if !added && result.static?
        sheet.add_row [result.type, result.key, ignored_flag(result.key), '', '', ''], style: style
      end
    end

    def build_key(result, usage)
      if result.lazy?
        path = usage.file.sub(%r{^app/views/}, '').sub(/\..+$/, '').sub('/_', '/').gsub('/', '.')
        path + usage.lazy_key
      else
        result.key
      end
    end

    def should_output?(usage, result, key)
      already_migrated = usage.file == 'config/initializers/copy_tuner.rb' || usage.code.include?("#{usage.lazy_key || result.key}_html")
      (!result.lazy? || incompatible_keys.include?(key)) && !already_migrated
    end

    def ignored_flag(key)
      ignored_keys.include?(key) ? 'Y' : 'N'
    end
  end
end
