require "bundler/setup"
Bundler.require
# require "sinatra/reloader" if development?
require "./models.rb"
configure :development do
  register Sinatra::Reloader
  also_reload "models/**/*"
  also_reload "helpers/**/*"
end
# Dir['./models/*.rb'].each { |model| require model}

require "open-uri"
require "net/http"
require "json"
require "jwt"

enable :sessions

api_prefix = "/api/v1"
api_prefix_admin = "/api/v1/admin"

helpers do
  def current_user(user_id)
    # session[:role] == "admin" ? User.find_by(id: session[:user]) : Member.find_by(id: session[:user])
    User.find_by(id: user_id)
  end

  def check_auth()
    token = request.env["HTTP_AUTHORIZATION"].split(" ").last
    secret = "my_secret0206"
    begin
      decode_token = JWT.decode(token, secret, true, { algorithm: "HS256" })
    rescue => e
      halt 401, { message: "Invalid token" }.to_json
    end
    if (decode_token[0]["role"] == "admin")
      user = User.find_by(id: decode_token[0]["user_id"])
      return { role: "admin", user: user }
    else
      member = Member.find_by(id: decode_token[0]["member_id"])
      return { role: "member", user: member }
    end
  end

  def jwt_decode
    token = request.env["HTTP_AUTHORIZATION"].split(" ").last
    secret = "my_secret0206"
    decode_token = JWT.decode(token, secret, true, { algorithm: "HS256" })
    return decode_token[0]["user_id"]
  end
end

# get 'dev' do

# end

before do
  response.headers["Access-Control-Allow-Origin"] = "*"
  response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept, Authorization, Token"
end

post "/dev/signup" do
  body_data = JSON.parse(request.body.read)
  user = User.new(name: body_data["name"], email: body_data["email"], password: body_data["password"])
  content_type "application/json"
  halt(200) if request.request_method == "OPTIONS"
  if user.valid?
    user.save
    { status: 200, message: :ok, content: "success" }.to_json
  else
    status 400
    { status: 400, message: user.errors.full_messages }.to_json
  end
end

post "/dev/signin" do
  body_data = JSON.parse(request.body.read)
  user = User.find_by(email: body_data["email"])
  content_type :json
  if user && user.authenticate(body_data["password"])
    payload = { user_id: user.id, role: "admin" }
    secret = "my_secret0206"
    token = JWT.encode(payload, secret, "HS256")
    { status: 200, message: "success", access_token: token }.to_json
  else
    { status: 400, message: "メールアドレスまたはパスワードが間違っています" }.to_json
  end
end

get "/api/v1/current_user" do
  content_type :json
  if check_auth[:role] == "admin" && check_auth[:user]
    { status: 200, message: "success", user: check_auth[:user] }.to_json
  elsif check_auth[:role] == "member" && check_auth[:user]
    { status: 200, message: "success", user: check_auth[:user] }.to_json
  else
    status 400
    { status: 400, message: "error" }.to_json
  end
end

get "/api/v1/admin/camps" do
  token = request.env["HTTP_AUTHORIZATION"].split(" ").last
  secret = "my_secret0206"
  decode_token = JWT.decode(token, secret, true, { algorithm: "HS256" })
  content_type :json
  if current_user(decode_token[0]["user_id"])
    camps = Camp.all
    { status: 200, message: "success", camps: camps }.to_json
  else
    { status: 400, message: "access denied" }.to_json
  end
end

get "/api/v1/admin/camp/:id" do
  token = request.env["HTTP_AUTHORIZATION"].split(" ").last
  secret = "my_secret0206"
  decode_token = JWT.decode(token, secret, true, { algorithm: "HS256" })
  content_type :json
  if current_user(decode_token[0]["user_id"])
    camp = Camp.find(params[:id])
    { status: 200, message: "success", camp: camp, camp_teams: camp.teams }.to_json
  else
    { status: 400, message: "access denied" }.to_json
  end
end

post "/api/v1/admin/camp" do
  body_data = JSON.parse(request.body.read)
  camp =
    Camp.create(
      name: body_data["name"],
      description: body_data["description"],
      location: body_data["location"],
      start_date: body_data["start_date"],
      end_date: body_data["end_date"],
      user_id: jwt_decode
    )
  halt(200) if request.request_method == "OPTIONS"
  content_type :json
  if camp.valid?
    camp.save
    { status: 200, message: "success", data: camp }.to_json
  else
    { status: 200, message: "failed", data: camp.errors.full_messages }.to_json
  end
end

put "/api/v1/admin/camp/:id" do
  body_data = JSON.parse(request.body.read)
  camp = Camp.find(params[:id])
  camp.update(
    name: body_data["name"],
    description: body_data["description"],
    location: body_data["location"],
    start_date: body_data["start_date"],
    end_date: body_data["end_date"]
  )
  halt(200) if request.request_method == "OPTIONS"
  content_type :json
  if camp.valid?
    camp.save
    { status: 200, message: "success", data: camp }.to_json
  else
    { status: 200, message: "failed", data: camp.errors.full_messages }.to_json
  end
end

delete "/api/v1/admin/camp/:id" do
  camp = Camp.find(params[:id])
  camp.destroy
  content_type :json
  { status: 200, message: "success" }.to_json
end

put "/api/v1/admin/camp/:id/archived" do
  camp = Camp.find(params[:id])
  camp.update(archived: true)
  content_type :json
  { status: 200, message: "success" }.to_json
end

put "/api/v1/admin/camp/:id/unarchived" do
  camp = Camp.find(params[:id])
  camp.update(archived: false)
  content_type :json
  { status: 200, message: "success" }.to_json
end

###### Team
# getTeam
get "/api/v1/admin/team/:unique_id" do
  team = Team.find_by(unique_id: params[:unique_id])
  posts =
    team
      .posts
      .left_joins(:user, :member)
      .select("posts.*, users.name AS user_name, members.name AS member_name")
      .order(created_at: :desc)
  content_type :json
  { status: 200, data: { team: team, posts: posts } }.to_json
end

# createTeam
post "/api/v1/admin/team" do
  body_data = JSON.parse(request.body.read)
  team =
    Team.create(
      alphabet: body_data["alphabet"],
      name: body_data["name"],
      camp_id: body_data["camp_id"],
      unique_id: SecureRandom.urlsafe_base64(4)
    )
  if team.valid?
    team.save
    { status: 200, message: "success", data: team }.to_json
  else
    { status: 200, message: "failed", data: team.errors.full_messages }.to_json
  end
end

# deleteTeam
delete "/api/v1/admin/team/:id" do
  team = Team.find(params[:id])
  team.destroy
  content_type :json
  { status: 200, message: "success destroy" }.to_json
end

###### Post
# createPost
post "/api/v1/team/:unique_id/post" do
  body_data = JSON.parse(request.body.read)
  team = Team.find_by(unique_id: params[:unique_id])
  if (check_auth[:role] === 'admin')
    post = team.posts.create(body: body_data["body"], user_id: check_auth[:user].id)
  else
    post = team.posts.create(body: body_data['body'], member_id: check_auth[:user].id)
  end
  # TODO: member or mentor????? check
  if post.valid?
    post.save
    { status: 200, message: "success", data: post }.to_json
  else
    { status: 200, message: "failed", data: post.errors.full_messages }.to_json
  end
end

# deletePost
delete "/api/v1/team/:unique_id/post/:id" do
  post = Post.find(params[:id])
  post.destroy
  content_type :json
  { status: 200, message: "success destroy" }.to_json
end

# archivePost
put "/api/v1/team/:unique_id/post/:id/archived" do
  post = Post.find(params[:id])
  post.update(archived: true)
  post.save
  content_type :json
  { status: 200, message: "success" }.to_json
end

###### Member
# signup member
post "/api/v1/team/:unique_id/signup" do
  body_data = JSON.parse(request.body.read)
  team = Team.find_by(unique_id: params[:unique_id])
  member = Member.create(name: body_data["name"], pass: body_data["pass"], team_id: team.id)
  if member.valid?
    member.save
    payload = { member_id: member.id, role: "member" }
    secret = "my_secret0206"
    token = JWT.encode payload, secret, "HS256"
    { status: 200, message: "success", data: member, access_token: token }.to_json
  else
    { status: 200, message: "failed", data: member.errors.full_messages }.to_json
  end
end

# login member
post "/api/v1/team/:unique_id/signin" do
  body_data = JSON.parse(request.body.read)
  team = Team.find_by(unique_id: params[:unique_id])
  member = Member.find_by(pass: body_data["pass"])
  content_type :json
  if member
    payload = { member_id: member.id, role: "member" }
    secret = "my_secret0206"
    token = JWT.encode(payload, secret, "HS256")
    { status: 200, message: "success", access_token: token }.to_json
  else
    { status: 200, message: member.errors.full_messages }.to_json
  end
end

#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# ここから下は消すぜ

# get "/" do
#   erb :index
# end

# get "/signout" do
#   session.clear
#   redirect "/"
# end

# get "/admin/signup" do
#   erb :a_sign_up
# end

# get "/admin/signin" do
#   erb :a_sign_in
# end

# get "/admin" do
#   @camps = Camp.all
#   erb :a_index
# end

# get "/admin/camp/:id" do
#   @camp = Camp.find(params[:id])
#   erb :a_camp
# end

# before "/:unique_id" do
#   redirect "/#{params[:unique_id]}/signin" if session[:user].nil?
# end

# get "/:unique_id" do
#   @team = Team.find_by(unique_id: params[:unique_id])
#   @posts = @team.posts.order(created_at: :desc)
#   erb :index
# end

# get "/:unique_id/signin" do
#   @team = Team.find_by(unique_id: params[:unique_id])
#   erb :sign_in
# end

# post api_prefix_admin + "/signup" do
#   user = User.create(name: params[:name], email: params[:email], password: params[:password])
#   session[:user] = user.id
#   session[:role] = "admin"
#   redirect "/"
# end

# post api_prefix_admin + "/signin" do
#   user = User.find_by(email: params[:email])
#   if user && user.authenticate(params[:password])
#     session[:user] = user.id
#     session[:role] = "admin"
#     redirect "/admin"
#   else
#     redirect "/admin/signin"
#   end
# end

# post api_prefix + "/camp/create" do
#   camp =
#     Camp.create(
#       name: params[:name],
#       location: params[:location],
#       start_date: params[:start_date],
#       end_date: params[:end_date],
#       description: params[:description],
#       user_id: current_user.id
#     )
#   redirect "/admin"
# end

# post api_prefix + "/camp/:id/update" do
#   camp = Camp.find(params[:id])
#   camp.update(
#     name: params[:name],
#     location: params[:location],
#     start_date: params[:start_date],
#     end_date: params[:end_date],
#     description: params[:description]
#   )
#   redirect "/admin"
# end

# post api_prefix + "/camp/:id/archive" do
#   camp = Camp.find(params[:id])
#   camp.update(archived: true)
#   redirect "/admin"
# end

# post api_prefix_admin + "/team/create" do
#   team =
#     Team.create(
#       alphabet: params[:alphabet],
#       name: params[:name],
#       camp_id: params[:camp_id],
#       unique_id: SecureRandom.urlsafe_base64(4)
#     )
#   redirect "/admin/camp/" + params[:camp_id].to_s
# end

# post api_prefix_admin + "/team/:id/update" do
#   team = Team.find(params[:id])
#   team.update(alphabet: params[:alphabet], name: params[:name])
#   redirect "/admin/camp/" + team.camp_id.to_s
# end

# post api_prefix_admin + "/team/:id/delete" do
#   team = Team.find(params[:id])
#   team.destroy
#   redirect "/admin/camp/" + team.camp_id.to_s
# end

# post api_prefix + "/:unique_id/signup" do
#   member = Member.create(name: params[:name], pass: params[:pass], team_id: params[:team_id])
#   redirect "/" + params[:unique_id]
# end

# post api_prefix + "/:unique_id/signin" do
#   member = Member.find_by(pass: params[:pass])
#   if member
#     session[:user] = member.id
#     session[:role] = "member"
#     redirect "/" + params[:unique_id]
#   else
#     redirect "/" + params[:unique_id] + "/signin"
#   end
# end

# post api_prefix + "/:unique_id/post" do
#   if session[:role] == "admin"
#     post = Post.create(body: params[:body], team_id: params[:team_id], user_id: current_user.id)
#   else
#     post = Post.create(body: params[:body], team_id: params[:team_id], member_id: current_user.id)
#   end
#   redirect "/" + params[:unique_id]
# end

options "*" do
  # response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
  # response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token"
  # response.headers["Access-Control-Allow-Origin"] = "*"
  200
end
