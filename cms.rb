require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def config_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test", __FILE__)
  else
    File.expand_path("..", __FILE__)
  end
end

def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def valid_name(name)
  name != ""
end

def load_users
  file_path = File.join(config_path, "users.yml")
  YAML.load(File.read(file_path))
end

def write_users_file(users)
  file_path = File.join(config_path, "users.yml")
  File.write(file_path, users.to_yaml)
end

def user_valid?(username, password)
  user_file = load_users

  user_file.any? do |user, pw|
    user == username && BCrypt::Password.new(pw) == password
  end
end

def username_invalid?(username)
  users = load_users

  if users.key?(username)
    "Username already exists."
  elsif username.size < 3
    "Username is too short, needs to be at least 3 letters."
  end
end

def password_invalid?(pw)
  "Password needs to be at least 8 characters long." if  pw.size < 8
end

def logged_in?
  session.key?(:user)
end

def verify_credentials
  unless logged_in?
    session[:message] = "You must be signed in to do that"
    redirect "/", 401
  end
end

configure do
  enable :sessions
  set :sessions_secret, "secret"
end

before do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
end

get "/" do
  erb :index
end

get "/new" do
  verify_credentials

  erb :new
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  verify_credentials

  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    @file_name = params[:filename]
    @content = File.read(file_path)

    erb :edit
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

post "/create" do
  verify_credentials

  unless valid_name(params[:filename])
    status 422
    session[:message] = "A name is required."
    erb :new
  else
    new_file = File.join(data_path, params[:filename])
    File.write(new_file, "")

    session[:message] = "#{params[:filename]} was created."
    redirect "/"
  end
end

post "/:filename" do
  verify_credentials

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  verify_credentials

  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)
  session[:message] = "#{params[:filename]} was deleted."
  redirect "/"
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  if user_valid?(params[:username], params[:password])
    session[:user] = params[:username]
    session[:message] = "Welcome!"

    redirect "/"
  else
    @username = params[:user]
    session[:message] = "Invalid Credentials"
    status 422

    erb :signin
  end
end

post "/users/signout" do
  session.delete(:user)
  session[:message] = "You have been signed out."

  redirect "/"
end

get "/users/signup" do
  erb :signup
end

post "/users/create_user" do
  @username = params[:username]
  pw = params[:password]

  error = username_invalid?(@username) || password_invalid?(pw)

  if error
    session[:message] = error
    status 422
    erb :signup
  else
    users = load_users
    hash_pw = BCrypt::Password.create(pw)
    users[@username] = hash_pw.to_s

    write_users_file(users)

    session[:message] = "You have signed up successfully."
    session[:user] = @username
    redirect "/"
  end
end

post "/users/delete" do
  username = params[:username]

  users = load_users
  users.delete(username)

  write_users_file(users)

  session.delete(:user)
  session[:message] = "User has been deleted."

  redirect "/"
end
