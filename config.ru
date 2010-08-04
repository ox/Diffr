require 'rubygems'
require 'sinatra'
require 'app'

set :run, false
set :environment, :development

run Sinatra::Application