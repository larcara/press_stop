require "sinatra"
require "sinatra/reloader" if development?
require "haml"
require "less"
require 'therubyracer'
require 'mongoid'
require 'omniauth-twitter'
require_relative "./atac_proxy.rb"
require 'json/ext' # required for .to_json


set :port, 8080
set :bind, '0.0.0.0'
set :sessions, true



class User
	include Mongoid::Document	
	field :username
	field :provider
	field :uid
	field :oauth_type, type: String
	field :oauth_token, type: String
end

class BusAlert
  include Mongoid::Document
  field :stop_number
  field :line
  field :percorso
  field :alert_data
  field :user_id, type: String
end

use OmniAuth::Builder do
  consumer_key="QhvRe8fJsjvFKrxysw8jkygj0"
  consumer_secret="HJCvYEPmuxYDiYMSOWg5oonw5zw2pyY148qmEj4IvdIUfvNL4b"
  provider :twitter, consumer_key, consumer_secret
end




enable :sessions


get '/login' do
  redirect to("/auth/twitter")
end

get '/logout' do
  session[:twitter_data]  = nil
end

get '/alerts' do
	current_user!
end

get '/add_alert' do
   current_user!
   @percorsi=[]
   haml :add_alert
end

post '/add_alert' do
   current_user!
   puts params.inspect
   if params[:percorso]==""
	@percorsi=AtacProxy.new().get_percorsi(params[:bus_line]) 
	haml :add_alert
   else
   	alert=BusAlert.find_or_create_by(user_id: @current_user.id, stop_number: params[:bus_stop], line: params[:bus_line], percorso: params[:percorso])
	redirect to("/alerts")
   end


end

get '/auth/twitter/callback' do
  if auth=env['omniauth.auth']
    u=User.find_or_create_by(provider: auth.provider, uid: auth.uid)
    u[:username]=auth.info.name
    u.save
    session[:user_id]=u.id
    puts env['omniauth.auth'].inspect
    redirect to("/alerts")
  else
    halt(401,'Not Authorized')
  end

end

get '/auth/failure' do
  params[:message]
end

def current_user!
 redirect to("/login") if session[:user_id].nil?
 @current_user = User.find(session[:user_id])
end

