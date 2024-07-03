# frozen_string_literal: true

require 'csv'
require 'set'

require 'roo'

module CopyTunerIncompatibleSearch
  class ReplaceCommand # rubocop:disable Metrics/ClassLength
    def self.run(usage_path, blurbs_path, output_path)
      self.new(usage_path, blurbs_path).run(output_path)
    end

    def initialize(usage_path, blurbs_path)
      @usage_path = usage_path
      @blurbs_path = blurbs_path
    end

    def run(output_path) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      # usages.xlsxから生成したUsageオブジェクトの配列
      usages = usage_sheet.each(type: 'Type', key: 'Key', file: 'File', line: 'Line').filter_map.with_index do |hash, i|
        next if i.zero? # skip header

        Usage.new(type: hash[:type], key: hash[:key], file: hash[:file], line: hash[:line])
      end
      # プロジェクト内で後方互換性のないキーの集合
      incompatible_keys = Set[*usages.select(&:static?).map(&:key)]
      # 使用箇所が判明しているUsageオブジェクトの配列（ただし、dynamicなキーを除く）
      used_usages = usages.select(&:used?)
      # _html付きのキーに変換する必要があるキーの集合
      keys_to_convert = Set[*used_usages.map(&:key)]
      # staticかつ使用箇所が判明しているUsageオブジェクトの配列を翻訳キーでグループ化
      static_usages_by_key = used_usages.select(&:static?).group_by(&:key)
      # lazyかつ使用箇所が判明しているUsageオブジェクトの配列を翻訳キーでグループ化
      lazy_usages_by_key = used_usages.select(&:lazy?).group_by(&:key)

      # blurbs.csvの全キーの集合と、特殊文字を含むキーの配列
      all_blurb_keys, keys_with_special_chars = parse_blurbs_csv
      # すでに_htmlで終わるキーが存在する後方互換性のないキーの集合
      underscore_converted_keys = Set[*incompatible_keys.select { |k| all_blurb_keys.include?("#{k}_html") }]
      # すでに.htmlで終わるキーが存在する後方互換性のないキーの集合
      dot_converted_keys = Set[*incompatible_keys.select { |k| all_blurb_keys.include?("#{k}.html") }]

      # コード上のキーを置換する必要があるキーの配列
      keys_for_code_replace = []
      # _html付きのキーを新たに登録しなければならないキーの配列
      newly_replaced_keys = []
      # 使用箇所が見つからなかった後方互換性のないキーの配列
      not_used_incompatible_keys = []
      # _html付きのキーを定義したCSVを保存する。このファイルはCopyTunerにアップロードするために使う
      CSV.open(output_path, 'wb') do |csv_out|
        CSV.parse(blurbs_csv_text, headers: true, quote_char: '"').each_with_index do |row, i|
          if i.zero?
            csv_out << row.headers
          end
          key = row['key']
          converted_key = "#{key}_html"
          if keys_to_convert.include?(key) && !dot_converted_keys.include?(key) && !underscore_converted_keys.include?(key)
            csv_out << [converted_key, *row[1..]]
            newly_replaced_keys << key
          end
          if keys_to_convert.include?(key)
            keys_for_code_replace << key
          elsif incompatible_keys.include?(key)
            not_used_incompatible_keys << key
          end
        end
      end

      replace_code_for_static_usages(static_usages_by_key, keys_for_code_replace, underscore_converted_keys, dot_converted_keys)
      replace_code_for_lazy_usages(lazy_usages_by_key, keys_for_code_replace, underscore_converted_keys, dot_converted_keys)

      existing_keys = keys_for_code_replace - newly_replaced_keys
      already_ignored_keys = search_ignored_keys.uniq
      keys_to_ignore = usages.reject(&:dynamic?).map(&:key).uniq - already_ignored_keys
      dynamic_count = usages.count(&:dynamic?)
      Result.new(newly_replaced_keys, existing_keys, not_used_incompatible_keys, keys_to_ignore, already_ignored_keys, keys_with_special_chars, dynamic_count)
    end

    private

    attr_reader :usage_path, :blurbs_path

    class Usage
      attr_reader :type, :key, :file

      def initialize(type:, key:, file:, line:)
        @type = type
        @key = key.to_s
        @file = file.to_s
        @line = line.to_s
      end

      def static?
        @type == 'static'
      end

      def lazy?
        @type == 'lazy'
      end

      def dynamic?
        @type == 'dynamic'
      end

      def used?
        !dynamic? && !@file.to_s.strip.empty?
      end

      def lazy_key
        return unless lazy?

        last_key = key.split('.').last
        ".#{last_key}"
      end

      def line
        raise 'line is not set' if @line.empty?

        @line.to_i
      end
    end

    class Result
      attr_reader :newly_replaced_keys, :existing_keys, :not_used_incompatible_keys, :keys_to_ignore, :already_ignored_keys, :keys_with_special_chars,
                  :dynamic_count

      def initialize(newly_replaced_keys, existing_keys, not_used_incompatible_keys, keys_to_ignore, already_ignored_keys, keys_with_special_chars, dynamic_count) # rubocop:disable Metrics/ParameterLists, Layout/LineLength
        @newly_replaced_keys = newly_replaced_keys
        @existing_keys = existing_keys
        @not_used_incompatible_keys = not_used_incompatible_keys
        @keys_to_ignore = keys_to_ignore
        @already_ignored_keys = already_ignored_keys
        @keys_with_special_chars = keys_with_special_chars
        @dynamic_count = dynamic_count
      end
    end

    def usage_sheet
      actual_xlsx = Roo::Spreadsheet.open(usage_path)
      actual_xlsx.sheet(0)
    end

    def blurbs_csv_text
      File.read(blurbs_path, encoding: 'bom|utf-8')
    end

    def search_ignored_keys
      eval(ignored_keys_text) # rubocop:disable Security/Eval
    end

    def ignored_keys_text
      `rails r "p CopyTunerClient::configuration.ignored_keys"`
    end

    def parse_blurbs_csv
      keys_with_special_chars = []
      all_blurb_keys = []
      CSV.parse(blurbs_csv_text, headers: true, quote_char: '"').each do |row|
        key = row['key']
        all_blurb_keys << key
        tr_range = detect_translation_range(row)
        translation = row[tr_range].join(' ')
        if translation.match?(/&#\d+;|&\w+;/) && !key.match?(/[_.]html$/)
          keys_with_special_chars << key
        end
      end
      [Set[*all_blurb_keys], keys_with_special_chars]
    end

    def detect_translation_range(row)
      start = 1
      finish = row.to_h.keys.index('created_at') - 1
      start..finish
    end

    def replace_code_for_lazy_usages(lazy_usages_by_key, keys_for_code_replace, underscore_converted_keys, dot_converted_keys)
      lazy_usages_by_key.each do |key, usages|
        next unless keys_for_code_replace.include?(key)

        usages.each do |usage|
          replace_code(usage, underscore_converted_keys, dot_converted_keys)
        end
      end
    end

    def replace_code_for_static_usages(static_usages_by_key, keys_for_code_replace, underscore_converted_keys, dot_converted_keys)
      static_usages_by_key.each do |key, usages|
        next unless keys_for_code_replace.include?(key)

        usages.each do |usage|
          replace_code(usage, underscore_converted_keys, dot_converted_keys)
        end
      end
    end

    def replace_code(usage, underscore_converted_keys, dot_converted_keys)
      lines = file_readlines(usage.file)
      if usage.lazy?
        lazy_key = usage.lazy_key
        regex = /(?<=['"])#{Regexp.escape(lazy_key.to_s)}(?=['"])/
      else
        regex = /(?<=['"])#{Regexp.escape(usage.key)}(?=['"])/
      end
      new_key = generate_html_key(usage, underscore_converted_keys, dot_converted_keys)
      lines[usage.line - 1].gsub!(regex, new_key)
      file_write(usage.file, lines.join)
    end

    def file_readlines(path)
      File.readlines(path)
    end

    def file_write(path, text)
      File.write(path, text)
    end

    # すでに_htmlまたは.htmlのキーが存在していればそのキーを、そうでなければ_html付きのキーを返す
    def generate_html_key(usage, underscore_converted_keys, dot_converted_keys)
      has_underscore = underscore_converted_keys.include?(usage.key)
      has_dot = dot_converted_keys.include?(usage.key)
      none = !has_underscore && !has_dot
      key = usage.lazy? ? usage.lazy_key : usage.key
      has_underscore || none ? "#{key}_html" : "#{key}.html"
    end
  end
end
