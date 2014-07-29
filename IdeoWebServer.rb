# encoding: utf-8
require 'rubygems'
require 'sinatra/base'
require "sinatra/reloader" if :development

require 'active_record'

require './lib/fuzzy/smith_waterman'
require './lib/kungfu/ZhEng_Calc'


db = URI.parse(ENV['DATABASE_URL'] || 'postgres://localhost/black')
ActiveRecord::Base.configurations['langware_db'] = {
  :adapter  => 'postgresql',
  :host     => db.host,
  :port     => db.port,
  :username => db.user,
  :password => db.password,
  :database => db.path[1..-1],
  :encoding => 'utf8'
}
require './model/model_langware'

class IdeoWebServer < Sinatra::Base

  set :mandarinos, JSON.parse(File.open("./lib/fuzzy/chistohash.json").read)
  set :static_cache_control, [:public, max_age: 60 * 60 * 24 * 30]

  configure :development do
    register Sinatra::Reloader
  end

  before do
    content_type :html, 'charset' => 'utf-8'
  end

  helpers do
    def spannify(header, spanarray, joiner='')
      "<span><span class='headterm'>#{header}</span> #{spanarray.join(joiner)}</span>"
    end
  end
  
  get '/' do
    @query, @sol = nil, nil
    erb :index
  end
  
  get '/numberutil/?' do
    query= params[:sourcestring]
    an= ZhEng_Calc.new(query)
    an.translate
    sol= an.tabulous
    pp= {"query"=>query, "sol"=>an.tabulous}.to_json
    return pp
  end

  get '/wordutil/?' do
    chi, lang = params[:term].strip, (params[:lang] || 'ct')
    pp = Pair.retrieve_pairs_by_chinese(chi, lang)
    qq = pp[params[:term]].map{|entry| "<span class='#{entry[:sts]}'>#{entry[:engt]}</span>"}
    return  {"query"=>chi, "sol"=>spannify("Translation #{chi} :<br/>", qq, ', ')}.to_json
  end
  
  get '/fuzzy_search/?' do
    chi = params[:term]

    pp= Chinese.fuzzysearch(chi, self)

    qq = pp.map do |entry| 

      unless entry[1]['c'] == chi
        wordspan = ""
        entry[1]['c'].each_char do |letter|
          wordspan << "<span class='#{chi.include?(letter) ? 'v2' : ''}'>#{letter}</span>"
        end
        "<span>#{wordspan} : #{entry[1]['e'].join(' // ')}</span><br />"
      end
    end
    return {"query"=>chi, "sol"=>spannify("Fuzzy Search : <br/>", qq)}.to_json
  end
  
  get '/deconstruct/?' do
    chi = params[:term]
    pp= Pair.deconstruct_chinese(params[:term])
    
    qq = []
    pp.each do |k, v|
      qq << "<span>#{k} : </span>"
      qq << v.map{|e| "<span class='#{e[:sts]}'>#{e[:engt]}</span>"}.join(', ')
      qq << "<br/>"
    end
    
    return {"query"=>chi, "sol"=>spannify("Identified Substrings : <br/>", qq)}.to_json
  end
  
  error do
    'shit!'
  end
  
  not_found do
    'not found'
  end


end  

