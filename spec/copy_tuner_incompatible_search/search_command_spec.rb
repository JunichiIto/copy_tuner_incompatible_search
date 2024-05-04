# frozen_string_literal: true

require 'matrix'
require 'roo'
require 'securerandom'

RSpec.describe CopyTunerIncompatibleSearch::SearchCommand do
  def generate_output_path
    "tmp/usages-#{SecureRandom.hex(10)}.xlsx"
  end

  def assert_xlsx_output(command, expected_matrix, key_count)
    output_path = generate_output_path
    expected_output = <<~OUTPUT
      Start
      Searching #{key_count} keys
      Finish
    OUTPUT
    expect do
      command.run(output_path)
    end.to change { File.exist?(output_path) }.from(false).and output(expected_output).to_stdout

    actual_xlsx = Roo::Spreadsheet.open(output_path)
    expect(actual_xlsx.to_matrix).to eq Matrix[*expected_matrix]
  end

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    FileUtils.rm_rf('tmp')
    FileUtils.mkdir_p('tmp')
  end

  describe '.run' do
    let(:command) { CopyTunerIncompatibleSearch::SearchCommand.new }

    describe 'type=static' do
      context 'when files found' do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.sample_message.hello_world
            en.sample_message.hello_world
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return('')

          allow(command).to receive(:grep_dynamic_keys).and_return('')

          allow(command).to receive(:grep_usage).and_return(<<~OUTPUT)
            app/views/home/index.html.erb:5:  <%= t('sample_message.hello_world') %>
            app/views/home/show.html.erb:10:  <p><%= t('sample_message.hello_world') %></p>
          OUTPUT

          allow(command).to receive(:ignored_keys_text).and_return('[]')
        end

        let(:expected_matrix) do
          [
            ['Type', 'Key', 'Ignored', 'File', 'Line', 'Code'],
            ['static', 'sample_message.hello_world', 'N', 'app/views/home/index.html.erb', 5, "<%= t('sample_message.hello_world') %>"],
            ['static', 'sample_message.hello_world', 'N', 'app/views/home/show.html.erb', 10, "<p><%= t('sample_message.hello_world') %></p>"],
          ]
        end

        it 'shows file path' do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context 'when no files found' do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.sample_message.hello_world
            en.sample_message.hello_world
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return('')

          allow(command).to receive(:grep_dynamic_keys).and_return('')

          allow(command).to receive(:grep_usage).and_return('')

          allow(command).to receive(:ignored_keys_text).and_return('[]')
        end

        let(:expected_matrix) do
          [
            ['Type', 'Key', 'Ignored', 'File', 'Line', 'Code'],
            ['static', 'sample_message.hello_world', 'N', nil, nil, nil],
          ]
        end

        it 'shows key only' do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context 'when already migrated' do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.sample_message.hello_world
            en.sample_message.hello_world
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return('')

          allow(command).to receive(:grep_dynamic_keys).and_return('')

          allow(command).to receive(:grep_usage).and_return(<<~OUTPUT)
            app/views/home/index.html.erb:5:  <%= t('sample_message.hello_world_html') %>
            app/views/home/show.html.erb:10:  <p><%= t('sample_message.hello_world_html') %></p>
            config/initializers/copy_tuner.rb:20:  'sample_message.hello_world',
          OUTPUT

          allow(command).to receive(:ignored_keys_text).and_return('["sample_message.hello_world"]')
        end

        let(:expected_matrix) do
          [
            ['Type', 'Key', 'Ignored', 'File', 'Line', 'Code'],
            ['static', 'sample_message.hello_world', 'Y', nil, nil, nil],
          ]
        end

        it 'ignores migrated row' do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context 'when ignored key is used' do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.sample_message.hello_world
            en.sample_message.hello_world
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return('')

          allow(command).to receive(:grep_dynamic_keys).and_return('')

          allow(command).to receive(:grep_usage).and_return(<<~OUTPUT)
            app/views/home/index.html.erb:5:  <%= t('sample_message.hello_world_html') %>
            app/views/home/show.html.erb:10:  <p><%= t('sample_message.hello_world') %></p>
            config/initializers/copy_tuner.rb:20:  'sample_message.hello_world',
          OUTPUT

          allow(command).to receive(:ignored_keys_text).and_return('["sample_message.hello_world"]')
        end

        let(:expected_matrix) do
          [
            ['Type', 'Key', 'Ignored', 'File', 'Line', 'Code'],
            ['static', 'sample_message.hello_world', 'Y', 'app/views/home/show.html.erb', 10, "<p><%= t('sample_message.hello_world') %></p>"],
          ]
        end

        it 'shows used file path' do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end
    end

    describe 'type=lazy' do
      context 'when lazy key is incompatible' do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.super_users.show.my_description
            en.super_users.show.my_description
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/super_users/show.html.erb:4:  <%= t('.my_description') %>
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return('')

          allow(command).to receive(:grep_usage).and_return('')

          allow(command).to receive(:ignored_keys_text).and_return('')
        end

        let(:expected_matrix) do
          [
            ['Type', 'Key', 'Ignored', 'File', 'Line', 'Code'],
            ['static', 'super_users.show.my_description', 'N', nil, nil, nil],
            ['lazy', 'super_users.show.my_description', 'N', 'app/views/super_users/show.html.erb', 4, "<%= t('.my_description') %>"],
          ]
        end

        it 'shows file path' do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context 'when several lazy keys exist in a row' do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.super_users.show.my_description
            ja.super_users.show.heading
            en.super_users.show.my_description
            en.super_users.show.heading
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/super_users/show.html.erb:4:  <%= t('.heading') %><%= t('.my_description') %>
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return('')

          allow(command).to receive(:grep_usage).and_return('')

          allow(command).to receive(:ignored_keys_text).and_return('')
        end

        let(:expected_matrix) do
          [
            ['Type', 'Key', 'Ignored', 'File', 'Line', 'Code'],
            ['static', 'super_users.show.heading', 'N', nil, nil, nil],
            ['static', 'super_users.show.my_description', 'N', nil, nil, nil],
            ['lazy', 'super_users.show.heading', 'N', 'app/views/super_users/show.html.erb', 4, "<%= t('.heading') %><%= t('.my_description') %>"],
            ['lazy', 'super_users.show.my_description', 'N', 'app/views/super_users/show.html.erb', 4, "<%= t('.heading') %><%= t('.my_description') %>"],
          ]
        end

        it 'shows all keys' do
          assert_xlsx_output(command, expected_matrix, 2)
        end
      end

      context 'when lazy key exists in a partial view' do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.super_users.my_form.my_heading
            en.super_users.my_form.my_heading
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/super_users/_my_form.html.erb:1:  <%= t('.my_heading') %>
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return('')

          allow(command).to receive(:grep_usage).and_return('')

          allow(command).to receive(:ignored_keys_text).and_return('')
        end

        let(:expected_matrix) do
          [
            ['Type', 'Key', 'Ignored', 'File', 'Line', 'Code'],
            ['static', 'super_users.my_form.my_heading', 'N', nil, nil, nil],
            ['lazy', 'super_users.my_form.my_heading', 'N', 'app/views/super_users/_my_form.html.erb', 1, "<%= t('.my_heading') %>"],
          ]
        end

        it 'shows file path' do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context 'when key does not match file path' do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.blogs.form.my_heading
            en.blogs.form.my_heading
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/super_users/_my_form.html.erb:1:  <%= t('.my_heading') %>
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return('')

          allow(command).to receive(:grep_usage).and_return('')

          allow(command).to receive(:ignored_keys_text).and_return('')
        end

        let(:expected_matrix) do
          [
            ['Type', 'Key', 'Ignored', 'File', 'Line', 'Code'],
            ['static', 'blogs.form.my_heading', 'N', nil, nil, nil],
          ]
        end

        it 'ignores key' do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context 'when already migrated' do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.super_users.my_form.my_heading
            en.super_users.my_form.my_heading
            ja.super_users.show.my_description
            en.super_users.show.my_description
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/super_users/_my_form.html.erb:1:  <%= t('.my_heading_html') %>
            app/views/super_users/show.html.erb:4:  <%= t('.my_description_html') %>
            config/initializers/copy_tuner.rb:20:  'super_users.show.my_description',
            config/initializers/copy_tuner.rb:21:  'super_users.my_form.my_heading',
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return('')

          allow(command).to receive(:grep_usage).and_return('')

          allow(command).to receive(:ignored_keys_text).and_return('["super_users.my_form.my_heading", "super_users.show.my_description"]')
        end

        let(:expected_matrix) do
          [
            ['Type', 'Key', 'Ignored', 'File', 'Line', 'Code'],
            ['static', 'super_users.my_form.my_heading', 'Y', nil, nil, nil],
            ['static', 'super_users.show.my_description', 'Y', nil, nil, nil],
          ]
        end

        it 'ignores migrated row' do
          assert_xlsx_output(command, expected_matrix, 2)
        end
      end

      context 'when ignored key is used' do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.super_users.my_form.my_heading
            en.super_users.my_form.my_heading
            ja.super_users.show.my_description
            en.super_users.show.my_description
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/super_users/_my_form.html.erb:1:  <%= t('.my_heading') %>
            app/views/super_users/show.html.erb:4:  <%= t('.my_description') %>
            config/initializers/copy_tuner.rb:20:  'super_users.show.my_description',
            config/initializers/copy_tuner.rb:21:  'super_users.my_form.my_heading',
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return('')

          allow(command).to receive(:grep_usage).and_return('')

          allow(command).to receive(:ignored_keys_text).and_return('["super_users.my_form.my_heading", "super_users.show.my_description"]')
        end

        let(:expected_matrix) do
          [
            ['Type', 'Key', 'Ignored', 'File', 'Line', 'Code'],
            ['static', 'super_users.my_form.my_heading', 'Y', nil, nil, nil],
            ['static', 'super_users.show.my_description', 'Y', nil, nil, nil],
            ['lazy', 'super_users.my_form.my_heading', 'Y', 'app/views/super_users/_my_form.html.erb', 1, "<%= t('.my_heading') %>"],
            ['lazy', 'super_users.show.my_description', 'Y', 'app/views/super_users/show.html.erb', 4, "<%= t('.my_description') %>"],
          ]
        end

        it 'shows used file path' do
          assert_xlsx_output(command, expected_matrix, 2)
        end
      end
    end

    describe 'type=dynamic' do
      before do
        allow(command).to receive(:detect_html_incompatible_keys).and_return('')

        allow(command).to receive(:grep_lazy_keys).and_return('')

        allow(command).to receive(:grep_dynamic_keys).and_return(<<~'OUTPUT')
          app/models/blog.rb:115:  message = I18n.t("sample.messages.#{type}")
        OUTPUT

        allow(command).to receive(:grep_usage).and_return('')

        allow(command).to receive(:ignored_keys_text).and_return('')
      end

      let(:expected_matrix) do
        [
          ['Type', 'Key', 'Ignored', 'File', 'Line', 'Code'],
          ['dynamic', nil, nil, 'app/models/blog.rb', 115, 'message = I18n.t("sample.messages.#{type}")'], # rubocop:disable Lint/InterpolationCheck
        ]
      end

      it 'shows file path' do
        assert_xlsx_output(command, expected_matrix, 0)
      end
    end

    context 'when no data found at all' do
      before do
        allow(command).to receive(:detect_html_incompatible_keys).and_return('')
        allow(command).to receive(:grep_lazy_keys).and_return('')
        allow(command).to receive(:grep_dynamic_keys).and_return('')
        allow(command).to receive(:grep_usage).and_return('')
        allow(command).to receive(:ignored_keys_text).and_return('')
      end

      let(:expected_matrix) do
        [
          %w[Type Key Ignored File Line Code],
        ]
      end

      it 'shows header only' do
        assert_xlsx_output(command, expected_matrix, 0)
      end
    end

    context 'when over 100 keys found' do
      before do
        keys = 1.upto(201).map { |i| "sample_message.hello_world_#{i}" }.join("\n")
        allow(command).to receive(:detect_html_incompatible_keys).and_return(keys)
        allow(command).to receive(:grep_lazy_keys).and_return('')
        allow(command).to receive(:grep_dynamic_keys).and_return('')
        allow(command).to receive(:grep_usage).and_return('')
        allow(command).to receive(:ignored_keys_text).and_return('')
      end

      let(:expected_matrix) do
        [
          %w[Type Key Ignored File Line Code],
        ]
      end

      let(:expected_output) do
        <<~OUTPUT
          Start
          Searching 201 keys
          100 / 201
          200 / 201
          Finish
        OUTPUT
      end

      it 'shows progress' do
        output_path = generate_output_path
        expect do
          command.run(output_path)
        end.to change { File.exist?(output_path) }.from(false).and output(expected_output).to_stdout
      end
    end
  end
end
