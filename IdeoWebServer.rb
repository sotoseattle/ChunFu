# encoding: utf-8
require 'rubygems'
require 'sinatra'
#require 'sinatra/base'
use Rack::Logger

require 'uri'
require 'net/http'
require 'open-uri'

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

  helpers do 
    def logger
      request.logger
    end
      
    #def validip(ip)
    #  #uri = URI::HTTP.build(:scheme=> 'http', :host=> 'geoip.maxmind.com',
    #  #      :path   => '/a', :query=> URI.encode_www_form(:l=> "S85zvqxU2ez8", :i=> ip))
    #  #response = Net::HTTP.get_response(uri)
    #  #response.body.encode('utf-8', 'iso-8859-1')!="TW" ? true : false
    #  true
    #end
    
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
    logger.info "QUERY-ING: #{query} |by| #{request.ip}"
    an= ZhEng_Calc.new(query)
    an.translate
    sol= an.tabulous
    pp= {"query"=>query, "sol"=>an.tabulous}.to_json
    response['Access-Control-Allow-Origin'] = '*'
    return pp
  end
  
  get '/cometopapa/?' do
    logger.info "QUERY-ING: #{params["term"]} |by| #{request.ip}"
    #pp= if validip(request.ip)
    #  JSON.generate(Pair.retrieve_pairs_by_chinese(params["term"], params["lang"]))
    #else
    #  nil
    #end
    pp= JSON.generate(Pair.retrieve_pairs_by_chinese(params["term"], params["lang"]))
    response['Access-Control-Allow-Origin'] = '*'
    return pp
  end
  
  get '/fuzzy/?' do
    logger.info "QUERY-ING: #{params["term"]} |by| #{request.ip}"
    #pp= if validip(request.ip)
    #  JSON.generate(Chinese.fuzzysearch(params["term"]))
    #else
    #  nil
    #end
    pp= JSON.generate(Chinese.fuzzysearch(params["term"]))
    response['Access-Control-Allow-Origin'] = '*'
    return pp
  end
  
  get '/deconstruct/?' do
    logger.info "QUERY-ING: #{params["term"]} |by| #{request.ip}"
    #pp= if validip(request.ip)
    #  JSON.generate(Pair.deconstruct_chinese(params["term"]))
    #else
    #  nil
    #end
    pp= JSON.generate(Pair.deconstruct_chinese(params["term"]))
    response['Access-Control-Allow-Origin'] = '*'
    return pp
  end
  
end
