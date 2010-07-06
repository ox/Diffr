require 'rubygems'
require 'sinatra'
require 'main'

set :run, false
set :environment, :production
set :authorization_realm, "PaperCrate"

run Sinatra::Application