require 'bundler/setup'
Bundler.require
# require "sinatra/reloader" if development?
require './models.rb'
configure :development do
  register Sinatra::Reloader
  also_reload 'models.rb'
  also_reload 'helpers/**/*'
end
# Dir['./models/*.rb'].each { |model| require model}

require 'open-uri'
require 'net/http'
require 'json'
require 'jwt'

Dotenv.load

prefix = '/api/v2'
prefix_admin = prefix + '/admin'

helpers do
  def authorized?
    halt 401, { message: 'Not authorized' }.to_json if request.env['HTTP_AUTHORIZATION'].nil?
    token = request.env['HTTP_AUTHORIZATION'].split(' ').last
    begin
      decode_token = JWT.decode(token, ENV['JWT_SECRET'], true, { algorithm: 'HS256' })
    rescue JWT::DecodeError
      halt 401, { message: 'invalid token' }.to_json
    end
    if (decode_token[0]['role'] === 'admin')
      user = User.find_by(id: decode_token[0]['user_id'])
      return { role: 'admin', user: user }
    else
      member = Member.find_by(id: decode_token[0]['member_id'])
      return { role: 'member', user: member }
    end
  end
end

before { response.headers['Access-Control-Allow-Origin'] = '*' }

options '*' do
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Accept, Authorization, Token'
end

get "#{prefix}/current_user" do
  content_type :json
  authorized?.to_json
end

#################### Mentor ####################
# Mentor Login
post "#{prefix_admin}/login" do
  content_type :json
  body_data = JSON.parse(request.body.read)
  user = User.find_by(email: body_data['email'])
  if user && user.authenticate(body_data['password'])
    payload = { user_id: user.id, role: 'admin' }
    token = JWT.encode(payload, ENV['JWT_SECRET'], 'HS256')
    status 200
    { status: 'success', message: 'User Login Successfully', token: token }.to_json
  else
    status 401
    { status: 'error', message: 'メールアドレスかパスワードが間違っています。' }.to_json
  end
end

# Mentor Register
post "#{prefix_admin}/register" do
  content_type :json
  body_data = JSON.parse(request.body.read)
  user =
    User.create(
      name: body_data['name'],
      email: body_data['email'],
      password: body_data['password'],
      password_confirmation: body_data['password_confirmation'],
    )
  if user
    status 201
    { status: 'success', message: 'User Register Successfully' }.to_json
  else
    status 400
    { status: 'error', message: user.errors.full_messages }.to_json
  end
end

#################### Camp ####################
# Create Camp
post "#{prefix_admin}/camp" do
  content_type :json
  halt 401, { message: 'access denied' }.to_json if authorized?[:role] != 'admin'
  body_data = JSON.parse(request.body.read)
  camp =
    Camp.create(
      name: body_data['name'],
      description: body_data['description'],
      location: body_data['location'],
      start_date: body_data['start_date'],
      end_date: body_data['end_date'],
      user_id: authorized?[:user].id,
    )
  if camp
    status 201
    { status: 'success', message: 'Camp Created Successfully' }.to_json
  else
    status 400
    { status: 'error', message: camp.errors.full_messages }.to_json
  end
end

# Read Camps
get "#{prefix_admin}/camps" do
  content_type :json
  halt 401, { message: 'access denied' }.to_json if authorized?[:role] != 'admin'
  Camp.all.to_json
end

# Read Camp
get "#{prefix_admin}/camp/:id" do
  content_type :json
  halt 401, { message: 'access denied' }.to_json if authorized?[:role] != 'admin'
  camp = Camp.find(params[:id])
  teams = camp.teams
  if camp
    { status: 'success', camp: camp, teams: teams }.to_json
  else
    status 404
    { status: 'error', message: 'Camp not found' }.to_json
  end
end

# Update Camp
put "#{prefix_admin}/camp/:id" do
  content_type :json
  halt 401, { message: 'access denied' }.to_json if authorized?[:role] != 'admin'
  body_data = JSON.parse(request.body.read)
  camp = Camp.find_by(id: params[:id])
  if camp
    camp.update(
      name: body_data['name'],
      description: body_data['description'],
      location: body_data['location'],
      start_date: body_data['start_date'],
      end_date: body_data['end_date'],
    )
    camp.save
    { message: 'Camp Updated Successfully' }.to_json
  else
    status 404
    { message: 'Camp Not Found' }.to_json
  end
end

#DeleteCamp
delete "#{prefix_admin}/camp/:id" do
  content_type :json
  halt 401, { message: 'access denied' }.to_json if authorized?[:role] != 'admin'

  camp = Camp.find_by(id: params[:id])
  if camp
    camp.destroy
    { message: 'Camp Deleted Successfully' }.to_json
  else
    status 404
    { message: 'Camp Not Found' }.to_json
  end
end

#################### Team ####################
# CreateTeam
post "#{prefix_admin}/camp/:camp_id/team" do
  content_type :json
  halt 401, { message: 'access denied' }.to_json if authorized?[:role] != 'admin'
  body_data = JSON.parse(request.body.read)
  camp = Camp.find_by(id: params['camp_id'])
  team =
    camp.teams.create(
      alphabet: body_data['alphabet'],
      name: body_data['name'],
      description: body_data['description'],
      color: body_data['color'],
      unique_id: SecureRandom.urlsafe_base64(4),
    )
  if team
    status 201
    { status: 'success', message: 'Team Created Successfully' }.to_json
  else
    status 400
    { status: 'error', message: team.errors.full_messages }.to_json
  end
end

# ReadTeams
get "#{prefix_admin}/camp/:camp_id/teams" do
  content_type :json
  halt 401, { message: 'access denied' }.to_json if authorized?[:role] != 'admin'
  camp = Camp.find_by(id: params[:camp_id])
  camp.teams.to_json
end

# ReadTeamAll
get "#{prefix}/team/:unique_id/alldata" do
  content_type :json
  authorized?
  team = Team.find_by(unique_id: params[:unique_id])
  if team
    posts =
      team
        .posts
        .left_joins(:user, :member)
        .select('posts.*, users.name AS user_name, members.name AS member_name')
        .order(created_at: :desc)
    if (authorized?[:role] == 'admin')
      members = team.members
    else
      members = team.members.select(:id, :name, :icon_url)
    end
    { status: 'success', team: team, posts: posts, members: members }.to_json
  else
    status 404
    { status: 'error', message: 'Team not found' }.to_json
  end
end

get "#{prefix}/team/:unique_id" do
  content_type :json
  team = Team.find_by(unique_id: params[:unique_id])
  if team
    { status: 'success', team: team }.to_json
  else
    status 404
    { status: 'error', message: 'Team not found' }.to_json
  end
end

# UpdateTeam
put "#{prefix_admin}/team/:id" do
  content_type :json
  halt 401, { message: 'access denied' }.to_json if authorized?[:role] != 'admin'
  body_data = JSON.parse(request.body.read)
  team = Team.find_by(id: params[:id])
  if team
    team.update(
      alphabet: body_data['alphabet'],
      name: body_data['name'],
      description: body_data['description'],
      color: body_data['color'],
    )
    { message: 'Team Updated Successfully' }.to_json
  else
    status 404
    { message: 'Team Not Found' }.to_json
  end
end

# DeleteTeam
delete "#{prefix_admin}/team/:id" do
  content_type :json
  halt 401, { message: 'access denied' }.to_json if authorized?[:role] != 'admin'
  team = Team.find_by(id: params[:id])
  if team
    team.destroy
    { message: 'Team Deleted Successfully' }.to_json
  else
    status 404
    { message: 'Team Not Found' }.to_json
  end
end

#################### Member ####################
# CreateMember
post "#{prefix}/team/:unique_id/member/register" do
  content_type :json
  body_data = JSON.parse(request.body.read)
  team = Team.find_by(unique_id: params[:unique_id])
  member = team.members.create(name: body_data['name'], pass: body_data['pass'])
  if member
    token = JWT.encode({ member_id: member.id, role: 'member' }, ENV['JWT_SECRET'], 'HS256')
    status 201
    { status: 'success', message: 'Member Created Successfully', token: token }.to_json
  else
    status 400
    { status: 'error', message: member.errors.full_messages }.to_json
  end
end

# ReadMembers
get "#{prefix}/team/:unique_id/members" do
  content_type :json
  team = Team.find_by(unique_id: params[:unique_id])
  authorized?[:role] == 'admin' ? team.members.to_json : team.members.select(:id, :name).to_json
end

# UpdateMember
put "#{prefix}/member/:id" do
  content_type :json
  body_data = JSON.parse(request.body.read)
  member = Member.find_by(id: params[:id])
  if member
    member.update(name: body_data['name'], pass: body_data['pass'])
    member.save
    { message: 'Member Updated Successfully' }.to_json
  else
    status 404
    { message: 'Member Not Found' }.to_json
  end
end

# DeleteMember
delete "#{prefix_admin}/member/:id" do
  member = Member.find_by(id: params[:id])
  if member
    member.destroy
    { message: 'Member Deleted Successfully' }.to_json
  else
    status 404
    { message: 'Member Not Found' }.to_json
  end
end

# MemberLogin
post "#{prefix}/team/:unique_id/member/login" do
  content_type :json
  body_data = JSON.parse(request.body.read)
  member = Member.find_by(pass: body_data['pass'])
  if member
    token = JWT.encode({ member_id: member.id, role: 'member' }, ENV['JWT_SECRET'], 'HS256')
    { status: 'success', token: token }.to_json
  else
    status 404
    { status: 'error', message: 'Member Not Found' }.to_json
  end
end

#################### Post ####################
# CreatePost
post "#{prefix}/team/:unique_id/post" do
  content_type :json
  body_data = JSON.parse(request.body.read)
  team = Team.find_by(unique_id: params[:unique_id])
  if authorized?[:role] == 'admin'
    post = team.posts.create(body: body_data['body'], user_id: authorized?[:user].id)
  else
    post = team.posts.create(body: body_data['body'], member_id: authorized?[:user].id)
  end

  if post
    status 201
    { status: 'success', message: 'Post Created Successfully' }.to_json
  else
    status 400
    { status: 'error', message: post.errors.full_messages }.to_json
  end
end

# ReadPosts
get "#{prefix}/team/:unique_id/posts" do
  content_type :json
  team = Team.find_by(unique_id: params[:unique_id])
  team
    .posts
    .left_joins(:user, :member)
    .select('posts.*, users.name AS user_name, members.name AS member_name')
    .order(created_at: :desc)
    .to_json
end

# ReadPost
get "#{prefix}/post/:id" do
  content_type :json
  post = Post.find_by(id: params[:id])
  if post
    post.to_json
  else
    status 404
    { message: 'Post Not Found' }.to_json
  end
end

# UpdatePost
put "#{prefix}/post/:id" do
  content_type :json
  halt 401, { message: 'access denied' }.to_json if authorized?[:role] != 'admin'
  body_data = JSON.parse(request.body.read)
  post = Post.find_by(id: params[:id])
  if post
    post.update(body: body_data['body'])
    post.save
    { message: 'Post Updated Successfully' }.to_json
  else
    status 404
    { message: 'Post Not Found' }.to_json
  end
end

# DeletePost
delete "#{prefix_admin}/post/:id" do
  content_type :json
  halt 401, { message: 'access denied' }.to_json if authorized?[:role] != 'admin'
  post = Post.find_by(id: params[:id])
  if post
    post.destroy
    { message: 'Post Deleted Successfully' }.to_json
  else
    status 404
    { message: 'Post Not Found' }.to_json
  end
end
