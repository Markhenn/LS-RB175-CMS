ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "about.md"

  end

  def test_viewing_a_text_document
    create_document "history.txt", "Ruby 0.95 released"

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_redirecting_non_existing_documents
    get "/notafile.txt"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.txt does not exist."

    get "/"
    assert_equal 200, last_response.status
    refute_includes last_response.body, "notafile.txt does not exist."
  end

  def test_viewing_markdown_files
    create_document "about.md", "<h1>Ruby is...</h1>"

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_viewing_edit_page_for_document_content
    create_document "history.txt"

    get "/history.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, "post"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_content_of_document
    create_document "changes.txt"

    post "/changes.txt", content: "Content Updated"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "changes.txt has been updated."

    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Content Updated"
  end
end
