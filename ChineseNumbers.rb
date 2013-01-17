# encoding: utf-8

require 'rubygems'
require 'sinatra'
require 'sinatra/base'

require 'json/pure'
#require 'awesome_print'

load './ZhEng_Calc.rb'

class ChineseNumbers

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
    return pp
  end
  
  
  get '/example_long/?' do
    erb :example_long
  end
  
end
