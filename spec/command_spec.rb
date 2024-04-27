# frozen_string_literal: true

require "matrix"
require "roo"
require "securerandom"

RSpec.describe CopyTunerIncompatibleSearch::Command do
  def generate_output_path
    "tmp/usages-#{SecureRandom.hex(10)}.xlsx"
  end

  def assert_xlsx_output(command, expected_matrix, key_count)
    output_path = generate_output_path
    expect {
      command.run(output_path)
    }.to change { File.exist?(output_path) }.from(false)
    .and output(<<~OUTPUT).to_stdout
      Start
      Searching #{key_count} keys
      Finish
    OUTPUT

    actual_xlsx = Roo::Spreadsheet.open(output_path)
    expect(actual_xlsx.to_matrix).to eq Matrix[*expected_matrix]
  end

  before do
    FileUtils.mkdir("tmp") unless Dir.exist?("tmp")
  end

  describe ".run" do
    let(:command) { CopyTunerIncompatibleSearch::Command.new }

    describe "type=static" do
      context "when files found" do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.sample.hello
            en.sample.hello
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return("")

          allow(command).to receive(:grep_dynamic_keys).and_return("")

          allow(command).to receive(:grep_usage).and_return(<<~OUTPUT)
            app/views/home/index.html.erb:5:  <%= t('sample.hello') %>
            app/views/home/show.html.erb:10:  <p><%= t('sample.hello') %></p>
          OUTPUT

          allow(command).to receive(:ignored_keys_text).and_return("[]")
        end

        let(:expected_matrix) do
          [
            ["Type", "Key", "Ignored", "File", "Line", "Code"],
            ["static", "sample.hello", "N", "app/views/home/index.html.erb", 5, "<%= t('sample.hello') %>"],
            ["static", "sample.hello", "N", "app/views/home/show.html.erb", 10, "<p><%= t('sample.hello') %></p>"],
          ]
        end

        it "shows file path" do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context "when no files found" do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.sample.hello
            en.sample.hello
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return("")

          allow(command).to receive(:grep_dynamic_keys).and_return("")

          allow(command).to receive(:grep_usage).and_return("")

          allow(command).to receive(:ignored_keys_text).and_return("[]")
        end

        let(:expected_matrix) do
          [
            ["Type", "Key", "Ignored", "File", "Line", "Code"],
            ["static", "sample.hello", "N", nil, nil, nil],
          ]
        end

        it "shows key only" do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context "when already migrated" do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.sample.hello
            en.sample.hello
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return("")

          allow(command).to receive(:grep_dynamic_keys).and_return("")

          allow(command).to receive(:grep_usage).and_return(<<~OUTPUT)
            app/views/home/index.html.erb:5:  <%= t('sample.hello_html') %>
            app/views/home/show.html.erb:10:  <p><%= t('sample.hello_html') %></p>
            config/initializers/copy_tuner.rb:20:  'sample.hello',
          OUTPUT

          allow(command).to receive(:ignored_keys_text).and_return('["sample.hello"]')
        end

        let(:expected_matrix) do
          [
            ["Type", "Key", "Ignored", "File", "Line", "Code"],
            ["static", "sample.hello", "Y", nil, nil, nil],
          ]
        end

        it "ignores migrated row" do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context "when ignored key is used" do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.sample.hello
            en.sample.hello
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return("")

          allow(command).to receive(:grep_dynamic_keys).and_return("")

          allow(command).to receive(:grep_usage).and_return(<<~OUTPUT)
            app/views/home/index.html.erb:5:  <%= t('sample.hello_html') %>
            app/views/home/show.html.erb:10:  <p><%= t('sample.hello') %></p>
            config/initializers/copy_tuner.rb:20:  'sample.hello',
          OUTPUT

          allow(command).to receive(:ignored_keys_text).and_return('["sample.hello"]')
        end

        let(:expected_matrix) do
          [
            ["Type", "Key", "Ignored", "File", "Line", "Code"],
            ["static", "sample.hello", "Y", "app/views/home/show.html.erb", 10, "<p><%= t('sample.hello') %></p>"],
          ]
        end

        it "shows used file path" do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end
    end

    describe "type=lazy" do
      context "when lazy key is incompatible" do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.users.show.description
            en.users.show.description
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/users/show.html.erb:4:  <%= t('.description') %>
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return("")

          allow(command).to receive(:grep_usage).and_return("")

          allow(command).to receive(:ignored_keys_text).and_return("")
        end

        let(:expected_matrix) do
          [
            ["Type", "Key", "Ignored", "File", "Line", "Code"],
            ["static", "users.show.description", "N", nil, nil, nil],
            ["lazy", "users.show.description", "N", "app/views/users/show.html.erb", 4, "<%= t('.description') %>"],
          ]
        end

        it "shows file path" do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context "when several lazy keys exist in a row" do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.users.show.description
            ja.users.show.heading
            en.users.show.description
            en.users.show.heading
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/users/show.html.erb:4:  <%= t('.heading') %><%= t('.description') %>
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return("")

          allow(command).to receive(:grep_usage).and_return("")

          allow(command).to receive(:ignored_keys_text).and_return("")
        end

        let(:expected_matrix) do
          [
            ["Type", "Key", "Ignored", "File", "Line", "Code"],
            ["static", "users.show.description", "N", nil, nil, nil],
            ["static", "users.show.heading", "N", nil, nil, nil],
            ["lazy", "users.show.heading", "N", "app/views/users/show.html.erb", 4, "<%= t('.heading') %><%= t('.description') %>"],
            ["lazy", "users.show.description", "N", "app/views/users/show.html.erb", 4, "<%= t('.heading') %><%= t('.description') %>"],
          ]
        end

        it "shows all keys" do
          assert_xlsx_output(command, expected_matrix, 2)
        end
      end

      context "when lazy key exists in a partial view" do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.users.form.heading
            en.users.form.heading
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/users/_form.html.erb:1:  <%= t('.heading') %>
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return("")

          allow(command).to receive(:grep_usage).and_return("")

          allow(command).to receive(:ignored_keys_text).and_return("")
        end

        let(:expected_matrix) do
          [
            ["Type", "Key", "Ignored", "File", "Line", "Code"],
            ["static", "users.form.heading", "N", nil, nil, nil],
            ["lazy", "users.form.heading", "N", "app/views/users/_form.html.erb", 1, "<%= t('.heading') %>"],
          ]
        end

        it "shows file path" do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context "when key does not match file path" do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.blogs.form.heading
            en.blogs.form.heading
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/users/_form.html.erb:1:  <%= t('.heading') %>
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return("")

          allow(command).to receive(:grep_usage).and_return("")

          allow(command).to receive(:ignored_keys_text).and_return("")
        end

        let(:expected_matrix) do
          [
            ["Type", "Key", "Ignored", "File", "Line", "Code"],
            ["static", "blogs.form.heading", "N", nil, nil, nil],
          ]
        end

        it "ignores key" do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context "when already migrated" do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.users.show.description
            en.users.show.description
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/users/show.html.erb:4:  <%= t('.description_html') %>
            config/initializers/copy_tuner.rb:20:  'users.show.description',
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return("")

          allow(command).to receive(:grep_usage).and_return("")

          allow(command).to receive(:ignored_keys_text).and_return('["users.show.description"]')
        end

        let(:expected_matrix) do
          [
            ["Type", "Key", "Ignored", "File", "Line", "Code"],
            ["static", "users.show.description", "Y", nil, nil, nil],
          ]
        end

        it "ignores migrated row" do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end

      context "when ignored key is used" do
        before do
          allow(command).to receive(:detect_html_incompatible_keys).and_return(<<~OUTPUT)
            ja.users.show.description
            en.users.show.description
          OUTPUT

          allow(command).to receive(:grep_lazy_keys).and_return(<<~OUTPUT)
            app/views/users/show.html.erb:4:  <%= t('.description') %>
            config/initializers/copy_tuner.rb:20:  'users.show.description',
          OUTPUT

          allow(command).to receive(:grep_dynamic_keys).and_return("")

          allow(command).to receive(:grep_usage).and_return("")

          allow(command).to receive(:ignored_keys_text).and_return('["users.show.description"]')
        end

        let(:expected_matrix) do
          [
            ["Type", "Key", "Ignored", "File", "Line", "Code"],
            ["static", "users.show.description", "Y", nil, nil, nil],
            ["lazy", "users.show.description", "Y", "app/views/users/show.html.erb", 4, "<%= t('.description') %>"],
          ]
        end

        it "shows used file path" do
          assert_xlsx_output(command, expected_matrix, 1)
        end
      end
    end

    describe "type=dynamic" do
      before do
        allow(command).to receive(:detect_html_incompatible_keys).and_return("")

        allow(command).to receive(:grep_lazy_keys).and_return("")

        allow(command).to receive(:grep_dynamic_keys).and_return(<<~'OUTPUT')
          app/models/blog.rb:115:  message = I18n.t("sample.messages.#{type}")
        OUTPUT

        allow(command).to receive(:grep_usage).and_return("")

        allow(command).to receive(:ignored_keys_text).and_return("")
      end

      let(:expected_matrix) do
        [
          ["Type", "Key", "Ignored", "File", "Line", "Code"],
          ["dynamic", nil, nil, "app/models/blog.rb", 115, 'message = I18n.t("sample.messages.#{type}")'],
        ]
      end

      it "shows file path" do
        assert_xlsx_output(command, expected_matrix, 0)
      end
    end

    context "when no data found at all" do
      before do
        allow(command).to receive(:detect_html_incompatible_keys).and_return("")
        allow(command).to receive(:grep_lazy_keys).and_return("")
        allow(command).to receive(:grep_dynamic_keys).and_return("")
        allow(command).to receive(:grep_usage).and_return("")
        allow(command).to receive(:ignored_keys_text).and_return("")
      end

      let(:expected_matrix) do
        [
          ["Type", "Key", "Ignored", "File", "Line", "Code"],
        ]
      end

      it "shows header only" do
        assert_xlsx_output(command, expected_matrix, 0)
      end
    end

    context "when over 100 keys found" do
      before do
        keys = 1.upto(201).map { |i| "sample.hello_#{i}" }.join("\n")
        allow(command).to receive(:detect_html_incompatible_keys).and_return(keys)
        allow(command).to receive(:grep_lazy_keys).and_return("")
        allow(command).to receive(:grep_dynamic_keys).and_return("")
        allow(command).to receive(:grep_usage).and_return("")
        allow(command).to receive(:ignored_keys_text).and_return("")
      end

      let(:expected_matrix) do
        [
          ["Type", "Key", "Ignored", "File", "Line", "Code"],
        ]
      end

      it "shows progress" do
        output_path = generate_output_path
        expect {
          command.run(output_path)
        }.to change { File.exist?(output_path) }.from(false)
        .and output(<<~OUTPUT).to_stdout
          Start
          Searching 201 keys
          100 / 201
          200 / 201
          Finish
        OUTPUT
      end
    end
  end
end
