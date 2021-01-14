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
    File.open(File.join(config_path, "users.yml"), "a") do |file|
      file.puts "---"
      file.puts "admin: $2a$12$pvtX5Gf2ZloWTIDoet0PmOceo5dwiiC33sQzMpOAGtn8YHzyXJeVi"
    end
  end

  def teardown
    FileUtils.rm_rf(data_path)
    File.delete(File.join(config_path, "users.yml"))
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { user: "admin" } }
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
    assert_equal "notafile.txt does not exist.", session[:message]
  end

  def test_viewing_markdown_files
    create_document "about.md", "# Ruby is..."

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_viewing_edit_page_for_document_content
    create_document "history.txt"

    get "/history.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_content_of_document
    post "/changes.txt", { content: "Content Updated" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Content Updated"
  end

  def test_create_page
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, %(<button type="submit")
    assert_includes last_response.body, %(<input name="filename")
  end

  def test_create_new_document
    post "/create", { filename: "new_file.txt" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "new_file.txt was created.", session[:message]

    get "/"
    assert_includes last_response.body, "new_file.txt"
  end

  def test_create_document_without_filename
    post "/create", { filename: "" }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_deleting_a_document
    create_document "to_delete.txt"

    post "/to_delete.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "to_delete.txt was deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %(href="to_delete.txt")
  end

  def test_sign_in_page
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_wrong_username_password
    post "/users/signin", username: "", password: ""

    assert_equal 422, last_response.status
    assert_nil session[:user]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signed_in_successfully
    post "/users/signin", username: "admin", password: "secret"

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:user]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_sign_out
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]
    assert_nil session[:user]
    assert_includes last_response.body, "Sign In"
  end

  def test_missing_credentials_for_sensitive_actions
    create_document "history.txt"
    signout_message = "You must be signed in to do that"

    get "/history.txt/edit"
    assert_equal 401, last_response.status
    assert_equal signout_message, session[:message]

    post "/changes.txt", { content: "Content Updated" }
    assert_equal 401, last_response.status
    assert_equal signout_message, session[:message]

    get "/new"
    assert_equal 401, last_response.status
    assert_equal signout_message, session[:message]

    post "/create", { filename: "new_file.txt" }
    assert_equal 401, last_response.status
    assert_equal signout_message, session[:message]

    post "/to_delete.txt/delete"
    assert_equal 401, last_response.status
    assert_equal signout_message, session[:message]
  end

  def test_sign_up_page
    get "/users/signup"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signup_user_successfully
    post "/users/create_user", { username: "new_user", password: "test1234" }
    assert_equal 302, last_response.status
    assert_equal "You have signed up successfully.", session[:message]
    assert_equal "new_user", session[:user]

    post "/users/signout"
    assert_equal "You have been signed out.", session[:message]
    assert_nil session[:user]

    post "/users/signin", username: "new_user", password: "test1234"
    assert_equal 302, last_response.status
    assert_equal "new_user", session[:user]
  end

  def test_signin_with_empty_or_taken_name
    post "/users/create_user", { username: "admin", password: "test1234" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Username already exists."
    assert_nil session[:user]

    post "/users/create_user", { username: "aa", password: "test1234" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Username is too short, needs to be at least 3 letters."
    assert_nil session[:user]
  end

  def test_signin_with_too_short_password
    post "/users/create_user", { username: "new_user", password: "test123" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Password needs to be at least 8 characters long."
    assert_nil session[:user]
  end

  def test_delete_user

  end
end
