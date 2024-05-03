# frozen_string_l

require 'securerandom'

RSpec.describe CopyTunerIncompatibleSearch::ReplaceCommand, :aggregate_failures do
  let(:output_path) { generate_output_path }

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    FileUtils.rm_rf('tmp')
    FileUtils.mkdir_p('tmp')
  end

  def generate_output_path
    "tmp/converted-#{SecureRandom.hex(10)}.csv"
  end

  def assert_csv(output_path, expected)
    actual = File.read(output_path)
    expect(actual).to eq(expected)
  end

  describe '.run' do
    let(:command) { CopyTunerIncompatibleSearch::ReplaceCommand.new('dummy-usages.xlsx', 'dummy-blurbs.csv') }

    context 'staticなキーを置換する場合' do
      context '_htmlや.htmlで終わるキーが定義されていない場合' do
        let(:blurbs_csv_text) do
          <<~CSV
            key,ja,created_at,ja updated_at,ja updater
            sample.hello,"Hello,<br/>world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
          CSV
        end
        let(:usage_data) do
          [
            { type: 'Type', key: 'Key', ignored: 'Ignored', file: 'File', line: 'Line' },
            { type: 'static', key: 'sample.hello', ignored: 'N', file: 'app/views/home/index.html.haml', line: 2 },
          ]
        end

        before do
          sheet_mock = double('sheet')
          allow(sheet_mock).to receive(:each).and_return(usage_data)
          allow(command).to receive(:usage_sheet).and_return(sheet_mock)
          allow(command).to receive(:blurbs_csv_text).and_return(blurbs_csv_text)
          allow(command).to receive(:file_readlines).and_return(<<~HAML.lines)
            %h1 Welcome
            %p= t('sample.hello')
            %h2 Contents
          HAML
          allow(command).to receive(:ignored_keys_text).and_return('[]')
        end

        it '_htmlに置換される / CSVにも出力される' do
          expect(command).to receive(:file_write).with('app/views/home/index.html.haml', <<~HAML)
            %h1 Welcome
            %p= t('sample.hello_html')
            %h2 Contents
          HAML
          expect do
            result = command.run(output_path)
            expect(result.newly_replaced_keys).to eq ['sample.hello']
            expect(result.existing_keys).to eq []
            expect(result.not_used_incompatible_keys).to eq []
            expect(result.keys_to_ignore).to eq ['sample.hello']
            expect(result.already_ignored_keys).to eq []
            expect(result.keys_with_special_chars).to eq []
          end.to change { File.exist?(output_path) }.from(false)

          expected_csv = <<~CSV
            key,ja,created_at,ja updated_at,ja updater
            sample.hello_html,"Hello,<br/>world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
          CSV
          assert_csv(output_path, expected_csv)
        end
      end

      context '_htmlで終わるキーが定義されている場合' do
        let(:blurbs_csv_text) do
          <<~CSV
            key,ja,created_at,ja updated_at,ja updater
            sample.hello,"Hello,<br/>world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
            sample.hello_html,"Hello,<br/>world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
          CSV
        end
        let(:usage_data) do
          [
            { type: 'Type', key: 'Key', ignored: 'Ignored', file: 'File', line: 'Line' },
            { type: 'static', key: 'sample.hello', ignored: 'N', file: 'app/views/home/index.html.haml', line: 2 },
          ]
        end

        before do
          sheet_mock = double('sheet')
          allow(sheet_mock).to receive(:each).and_return(usage_data)
          allow(command).to receive(:usage_sheet).and_return(sheet_mock)
          allow(command).to receive(:blurbs_csv_text).and_return(blurbs_csv_text)
          allow(command).to receive(:file_readlines).and_return(<<~HAML.lines)
            %h1 Welcome
            %p= t('sample.hello')
            %h2 Contents
          HAML
          allow(command).to receive(:ignored_keys_text).and_return('[]')
        end

        it '_htmlに置換される / CSVには出力されない' do
          expect(command).to receive(:file_write).with('app/views/home/index.html.haml', <<~HAML)
            %h1 Welcome
            %p= t('sample.hello_html')
            %h2 Contents
          HAML
          expect do
            result = command.run(output_path)
            expect(result.newly_replaced_keys).to eq []
            expect(result.existing_keys).to eq ['sample.hello']
            expect(result.not_used_incompatible_keys).to eq []
            expect(result.keys_to_ignore).to eq ['sample.hello']
            expect(result.already_ignored_keys).to eq []
            expect(result.keys_with_special_chars).to eq []
          end.to change { File.exist?(output_path) }.from(false)

          expected_csv = <<~CSV
            key,ja,created_at,ja updated_at,ja updater
          CSV
          assert_csv(output_path, expected_csv)
        end
      end

      describe '.htmlで終わるキーが定義されている場合' do
        let(:blurbs_csv_text) do
          <<~CSV
            key,ja,created_at,ja updated_at,ja updater
            sample.hello,"Hello,<br/>world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
            sample.hello.html,"Hello,<br/>world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
          CSV
        end
        let(:usage_data) do
          [
            { type: 'Type', key: 'Key', ignored: 'Ignored', file: 'File', line: 'Line' },
            { type: 'static', key: 'sample.hello', ignored: 'N', file: 'app/views/home/index.html.haml', line: 2 },
          ]
        end

        before do
          sheet_mock = double('sheet')
          allow(sheet_mock).to receive(:each).and_return(usage_data)
          allow(command).to receive(:usage_sheet).and_return(sheet_mock)
          allow(command).to receive(:blurbs_csv_text).and_return(blurbs_csv_text)
          allow(command).to receive(:file_readlines).and_return(<<~HAML.lines)
            %h1 Welcome
            %p= t('sample.hello')
            %h2 Contents
          HAML
          allow(command).to receive(:ignored_keys_text).and_return('[]')
        end

        it '.htmlに置換される / CSVには出力されない' do
          expect(command).to receive(:file_write).with('app/views/home/index.html.haml', <<~HAML)
            %h1 Welcome
            %p= t('sample.hello.html')
            %h2 Contents
          HAML
          expect do
            result = command.run(output_path)
            expect(result.newly_replaced_keys).to eq []
            expect(result.existing_keys).to eq ['sample.hello']
            expect(result.not_used_incompatible_keys).to eq []
            expect(result.keys_to_ignore).to eq ['sample.hello']
            expect(result.already_ignored_keys).to eq []
            expect(result.keys_with_special_chars).to eq []
          end.to change { File.exist?(output_path) }.from(false)

          expected_csv = <<~CSV
            key,ja,created_at,ja updated_at,ja updater
          CSV
          assert_csv(output_path, expected_csv)
        end
      end
    end

    context 'lazyなキーを置換する場合' do
      let(:blurbs_csv_text) do
        <<~CSV
          key,ja,created_at,ja updated_at,ja updater
          home.index.hello,"Hello,<br/>world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
        CSV
      end
      let(:usage_data) do
        [
          { type: 'Type', key: 'Key', ignored: 'Ignored', file: 'File', line: 'Line' },
          { type: 'lazy', key: 'home.index.hello', ignored: 'N', file: 'app/views/home/index.html.haml', line: 2 },
        ]
      end

      before do
        sheet_mock = double('sheet')
        allow(sheet_mock).to receive(:each).and_return(usage_data)
        allow(command).to receive(:usage_sheet).and_return(sheet_mock)
        allow(command).to receive(:blurbs_csv_text).and_return(blurbs_csv_text)
        allow(command).to receive(:file_readlines).and_return(<<~HAML.lines)
          %h1 Welcome
          %p= t('.hello')
          %h2 Contents
        HAML
        allow(command).to receive(:ignored_keys_text).and_return('[]')
      end

      it 'creates csv and returns data' do
        expect(command).to receive(:file_write).with('app/views/home/index.html.haml', <<~HAML)
          %h1 Welcome
          %p= t('.hello_html')
          %h2 Contents
        HAML
        expect do
          result = command.run(output_path)
          expect(result.newly_replaced_keys).to eq ['home.index.hello']
          expect(result.existing_keys).to eq []
          expect(result.not_used_incompatible_keys).to eq []
          expect(result.keys_to_ignore).to eq ['home.index.hello']
          expect(result.already_ignored_keys).to eq []
          expect(result.keys_with_special_chars).to eq []
        end.to change { File.exist?(output_path) }.from(false)

        expected_csv = <<~CSV
          key,ja,created_at,ja updated_at,ja updater
          home.index.hello_html,"Hello,<br/>world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
        CSV
        assert_csv(output_path, expected_csv)
      end
    end

    context '翻訳に特殊文字が含まれる場合' do
      context '_htmlや.htmlで終わらない場合' do
        let(:blurbs_csv_text) do
          <<~CSV
            key,ja,created_at,ja updated_at,ja updater
            views.pagination.first,"&laquo; 先頭",2013/05/28 10:51:09,2013/05/28 10:51:11,
            views.pagination.last,"最後 &#187;",2013/05/28 10:51:09,2013/05/28 10:51:11,
          CSV
        end
        let(:usage_data) do
          [
            { type: 'Type', key: 'Key', ignored: 'Ignored', file: 'File', line: 'Line' },
          ]
        end

        before do
          sheet_mock = double('sheet')
          allow(sheet_mock).to receive(:each).and_return(usage_data)
          allow(command).to receive(:usage_sheet).and_return(sheet_mock)
          allow(command).to receive(:blurbs_csv_text).and_return(blurbs_csv_text)
          allow(command).to receive(:ignored_keys_text).and_return('[]')
        end

        it 'keys_with_special_chars に追加される' do
          expect do
            result = command.run(output_path)
            expect(result.newly_replaced_keys).to eq []
            expect(result.existing_keys).to eq []
            expect(result.not_used_incompatible_keys).to eq []
            expect(result.keys_to_ignore).to eq []
            expect(result.already_ignored_keys).to eq []
            expect(result.keys_with_special_chars).to eq ['views.pagination.first', 'views.pagination.last']
          end.to change { File.exist?(output_path) }.from(false)

          expected_csv = <<~CSV
            key,ja,created_at,ja updated_at,ja updater
          CSV
          assert_csv(output_path, expected_csv)
        end
      end

      context '_htmlや.htmlで終わる場合' do
        let(:blurbs_csv_text) do
          <<~CSV
            key,ja,created_at,ja updated_at,ja updater
            views.pagination.first_html,"&laquo; 先頭",2013/05/28 10:51:09,2013/05/28 10:51:11,
            views.pagination.last.html,"最後 &#187;",2013/05/28 10:51:09,2013/05/28 10:51:11,
          CSV
        end
        let(:usage_data) do
          [
            { type: 'Type', key: 'Key', ignored: 'Ignored', file: 'File', line: 'Line' },
          ]
        end

        before do
          sheet_mock = double('sheet')
          allow(sheet_mock).to receive(:each).and_return(usage_data)
          allow(command).to receive(:usage_sheet).and_return(sheet_mock)
          allow(command).to receive(:blurbs_csv_text).and_return(blurbs_csv_text)
          allow(command).to receive(:ignored_keys_text).and_return('[]')
        end

        it 'keys_with_special_chars に追加されない' do
          expect do
            result = command.run(output_path)
            expect(result.newly_replaced_keys).to eq []
            expect(result.existing_keys).to eq []
            expect(result.not_used_incompatible_keys).to eq []
            expect(result.keys_to_ignore).to eq []
            expect(result.already_ignored_keys).to eq []
            expect(result.keys_with_special_chars).to eq []
          end.to change { File.exist?(output_path) }.from(false)

          expected_csv = <<~CSV
            key,ja,created_at,ja updated_at,ja updater
          CSV
          assert_csv(output_path, expected_csv)
        end
      end
    end

    context 'blurbsのキーに問題がない場合' do
      let(:blurbs_csv_text) do
        <<~CSV
          key,ja,created_at,ja updated_at,ja updater
          sample.hello_html,"Hello,<br/>world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
          sample.bye,"Bye, world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
        CSV
      end
      let(:usage_data) do
        [
          { type: 'Type', key: 'Key', ignored: 'Ignored', file: 'File', line: 'Line' },
        ]
      end

      before do
        sheet_mock = double('sheet')
        allow(sheet_mock).to receive(:each).and_return(usage_data)
        allow(command).to receive(:usage_sheet).and_return(sheet_mock)
        allow(command).to receive(:blurbs_csv_text).and_return(blurbs_csv_text)
        allow(command).to receive(:ignored_keys_text).and_return('[]')
      end

      it '置換やCSV出力の対象にならない' do
        expect do
          result = command.run(output_path)
          expect(result.newly_replaced_keys).to eq []
          expect(result.existing_keys).to eq []
          expect(result.not_used_incompatible_keys).to eq []
          expect(result.keys_to_ignore).to eq []
          expect(result.already_ignored_keys).to eq []
          expect(result.keys_with_special_chars).to eq []
        end.to change { File.exist?(output_path) }.from(false)

        expected_csv = <<~CSV
          key,ja,created_at,ja updated_at,ja updater
        CSV
        assert_csv(output_path, expected_csv)
      end
    end

    context 'staticだが、使用箇所が見つからない場合' do
      let(:blurbs_csv_text) do
        <<~CSV
          key,ja,created_at,ja updated_at,ja updater
          sample.hello,"Hello,<br/>world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
        CSV
      end
      let(:usage_data) do
        [
          { type: 'Type', key: 'Key', ignored: 'Ignored', file: 'File', line: 'Line' },
          { type: 'static', key: 'sample.hello', ignored: 'N', file: nil, line: nil },
        ]
      end

      before do
        sheet_mock = double('sheet')
        allow(sheet_mock).to receive(:each).and_return(usage_data)
        allow(command).to receive(:usage_sheet).and_return(sheet_mock)
        allow(command).to receive(:blurbs_csv_text).and_return(blurbs_csv_text)
        allow(command).to receive(:ignored_keys_text).and_return('[]')
      end

      it 'not_used_incompatible_keysに追加される / CSVには出力されない' do
        expect do
          result = command.run(output_path)
          expect(result.newly_replaced_keys).to eq []
          expect(result.existing_keys).to eq []
          expect(result.not_used_incompatible_keys).to eq ['sample.hello']
          expect(result.keys_to_ignore).to eq ['sample.hello']
          expect(result.already_ignored_keys).to eq []
          expect(result.keys_with_special_chars).to eq []
        end.to change { File.exist?(output_path) }.from(false)

        expected_csv = <<~CSV
          key,ja,created_at,ja updated_at,ja updater
        CSV
        assert_csv(output_path, expected_csv)
      end
    end

    context 'すでにignored_keysに追加されている場合' do
      let(:blurbs_csv_text) do
        <<~CSV
          key,ja,created_at,ja updated_at,ja updater
          sample.hello,"Hello,<br/>world!",2013/05/28 10:51:09,2013/05/28 10:51:11,
        CSV
      end
      let(:usage_data) do
        [
          { type: 'Type', key: 'Key', ignored: 'Ignored', file: 'File', line: 'Line' },
          { type: 'static', key: 'sample.hello', ignored: 'N', file: nil, line: nil },
        ]
      end

      before do
        sheet_mock = double('sheet')
        allow(sheet_mock).to receive(:each).and_return(usage_data)
        allow(command).to receive(:usage_sheet).and_return(sheet_mock)
        allow(command).to receive(:blurbs_csv_text).and_return(blurbs_csv_text)
        allow(command).to receive(:ignored_keys_text).and_return('["sample.hello"]')
      end

      it 'keys_to_ignoreではなくalready_ignored_keysに追加される' do
        expect do
          result = command.run(output_path)
          expect(result.newly_replaced_keys).to eq []
          expect(result.existing_keys).to eq []
          expect(result.not_used_incompatible_keys).to eq ['sample.hello']
          expect(result.keys_to_ignore).to eq []
          expect(result.already_ignored_keys).to eq ['sample.hello']
          expect(result.keys_with_special_chars).to eq []
        end.to change { File.exist?(output_path) }.from(false)

        expected_csv = <<~CSV
          key,ja,created_at,ja updated_at,ja updater
        CSV
        assert_csv(output_path, expected_csv)
      end
    end
  end
end
