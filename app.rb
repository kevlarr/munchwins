require 'sinatra'
require 'pg'

require 'omniauth-facebook'

require_relative './lib/database'
require_relative './lib/models/game'
require_relative './lib/models/user'
require_relative './lib/models/player'

use Rack::Session::Cookie, {
  secret: ENV["SECRET"],
  expire_after:  43300
}

use OmniAuth::Builder do
  provider :facebook, ENV["FB_ID"], ENV["FB_SECRET"]
end


# FACEBOOK authentication
# Use:
#   env['omniauth.auth']['info']['name']
#   env['omniauth.auth']['info']['image']
#   env['omniauth.auth']['uid']


get '/login' do
  redirect to('/auth/facebook')
end

get '/auth/facebook/callback' do
  env['omniauth.auth'] ? session[:user] = true : halt(401, 'Not Authorized')
  uid = env['omniauth.auth']['uid']

  user =
    if User.exist?(uid)
      User.from_uid(uid)
    else
      User.create(uid, env['omniauth.auth']['info']['name'])
    end

  session[:username] = user.name
  session[:user_id] = user.id
  session[:pic] = env['omniauth.auth']['info']['image']

  redirect '/'
end

get '/logout' do
  session.clear
  redirect '/'
end

get 'auth/failure' do
  params[:message]
end

get '/' do
  erb :index
end

get '/game' do
  game =
    if User.open_game?(session[:user_id])
      Game.from_userid(session[:user_id])
    else
      Game.new(session[:user_id])
    end

  session[:game_id] = game.id

  erb :'game/game', layout: :'layouts/game', locals: {game: game}
end

# Add player screen

get '/game/add' do
  # Return to player setup
  game = Game.from_userid(session[:user_id])
  game.state = 'start'
  redirect '/game'
end

post '/game/add' do
  sanitize(params)
  name = params['player']['name']
  gender = params['player']['gender']
  Player.create(name, gender, session[:game_id])
  redirect '/game'
end

get '/game/delete/:id' do
  sanitize(params)
  Player.delete(params[:id])
  redirect '/game'
end

# Game scores and player behavior

get '/game/scores' do
  # Return to scores page
  game = Game.from_userid(session[:user_id])
  game.state = 'scores'
  redirect '/game'
end

get '/player/:id/up' do
  sanitize(params)
  Player.from_id(params[:id]).level_up
  redirect '/game'
end

get '/player/:id/down' do
  sanitize(params)
  Player.from_id(params[:id]).level_down
  redirect '/game'
end

get '/player/:id/sexchange' do
  sanitize(params)
  Player.from_id(params[:id]).change_sex
  redirect '/game'
end
