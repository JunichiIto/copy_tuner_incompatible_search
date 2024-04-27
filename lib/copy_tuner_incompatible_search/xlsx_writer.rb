# frozen_string_literal: true

module CopyTunerIncompatibleSearch
  class XlsxWriter
    def self.save_to(results, incompatible_keys, ignored_keys, output_path)
      self.new(results, incompatible_keys, ignored_keys).save_to(output_path)
    end

    def initialize(results, incompatible_keys, ignored_keys)
      @results = results
      @incompatible_keys = incompatible_keys
      @ignored_keys = ignored_keys
    end

    def save_to(output_path)
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
        unless result.dynamic?
          full_key = result.full_key_for(usage)
          next unless should_output?(usage, result, full_key)

          ignored = ignored_flag(full_key)
        end
        sheet.add_row [result.type, full_key, ignored.to_s, usage.file, usage.line, usage.code], style: style
        added = true
      end
      if result.static? && !added
        sheet.add_row [result.type, result.key, ignored_flag(result.key), '', '', ''], style: style
      end
    end

    def should_output?(usage, result, full_key)
      incompatible_keys.include?(full_key) && !result.already_migrated?(usage)
    end

    def ignored_flag(key)
      ignored_keys.include?(key) ? 'Y' : 'N'
    end
  end
end
