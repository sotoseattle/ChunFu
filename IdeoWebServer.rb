# encoding: utf-8
require 'rubygems'
require 'sinatra'
#require 'sinatra/base'

require 'uri'
require 'active_record'
require 'sinatra/activerecord'
require 'ar_pg_array'

#require 'json/pure'
require 'json/ext'

require 'awesome_print'

require './lib/fuzzy/smith_waterman'
require './lib/kungfu/ZhEng_Calc'
#load './ZhEng_Calc.rb'


db = URI.parse(ENV['DATABASE_URL'] || 'postgres://localhost/langware_development')
ActiveRecord::Base.configurations["langware_db"] = {
  :adapter  => 'postgresql',
  :host     => db.host,
  :port     => db.port,
  :username => db.user,
  :password => db.password,
  :database => db.path[1..-1],
  :encoding => 'utf8'
}
require './model/model_langware'


class IdeoWebServer
  
  set :mandarinos, JSON.parse(File.open("./lib/fuzzy/chistohash.json").read)

  configure do 
    JSON.generator = JSON::Ext::Generator
  end

  before do
    content_type :html, 'charset' => 'utf-8'
  end
  
  get '/' do
    @query, @sol = nil, nil
    erb :index
  end
  
  get '/computa/?' do
    query= params["sourcestring"]
    an= ZhEng_Calc.new(query)
    an.translate
    sol= an.tabulous
    pp= {"query"=>query, "sol"=>an.tabulous}.to_json
    response['Access-Control-Allow-Origin'] = '*'
    return pp
  end
  
  get '/cometopapa/?' do
    response['Access-Control-Allow-Origin'] = '*'
    pp= JSON.generate(Pair.retrieve_pairs_by_chinese(params["term"], params["lang"]))
    return pp
  end
  
  get '/fuzzy/?' do
    response['Access-Control-Allow-Origin'] = '*'
    pp= JSON.generate(Chinese.fuzzysearch(params["term"]))
    return pp
  end
  
  
  
end
