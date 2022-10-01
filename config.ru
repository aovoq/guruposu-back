require 'bundler'
Bundler.require
require 'sinatra/activerecord'

Time.zone = "Tokyo"
ActiveRecord::Base.default_timezone = :local

Dotenv.load

Cloudinary.config do |config|
    config.cloud_name = ENV['CLOUD_NAME']
    config.api_key    = ENV['CLOUDINARY_API_KEY']
    config.api_secret = ENV['CLOUDINARY_API_SECRET']
end

require './app'
run Sinatra::Application
