# encoding: utf-8

require 'rubygems'
require 'sinatra'
require 'sinatra/base'

require 'json/pure'
require 'awesome_print'

load './ZhEng_Calc.rb'

class ChineseNumbers

  configure do
  end

  #before do
  #  puts "connecting from: #{request.ip}"
  #  if request.ip.to_s.match(/(\d+)\.(\d+)\.(\d+)\.(\d+)/)
  #    ipn= (16777216*$1.to_i) + (65536*$2.to_i) + (256*$3.to_i) + ($1.to_i)
  #    if ipn.between?(3409969152, 3410755583) || # TW
  #       ipn.between?(3412000768, 3412002815)    # CN
  #      halt(404, "Not found")
  #    end
  #  else
  #    halt(404, "Not found")
  #  end
  #end
   
   
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
  
  
end
