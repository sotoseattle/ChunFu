# -*- coding: utf-8 -*-
require 'active_record'
require 'ar_pg_array'

class Chinese < ActiveRecord::Base
  establish_connection 'langware_db'
	has_many :pairs
	
	# FUZZY SEARCH
  
  def self.fuzzysearch(chist)
    len= chist.size
    chist= chist.strip.chomp.split("")
    distances= {}
    # Find the terms with all the characters in them
    # substitute with a way to permutate all possible options
    len.downto 2 do |i|
      universe= chist.combination(i).to_a
      universe.each do |array_chars|
        sol= nil
        array_chars.each_with_index do |cc, pos|
          sol= (pos==0 ? settings.mandarinos[array_chars[0]] : (sol & settings.mandarinos[cc]))
        end
        # here we compute the distances from the original string to each intersected term
        sol.each do |common_term|
          unless distances[common_term]
            c= Chinese.find(common_term)
            sa = StringAlign.new(chist.join, c.term)
            sa.align!
            if sa.score>=len  # we cutout at 50% max level
              e= []
              c.pairs.all(:conditions=>{:status=>['v','c']}, :order=> "rank").select do |p|
                e<< p.english[:term]
              end
              if e!=[]
                distances[common_term]={"d"=>sa.score, "e"=> e, "c"=>c.term}
                if distances.size>50 
                  break
                end
              end
            end
          end
        end
      end
      # here filter of solutions ???? to cut if too many computations
    end
    
    # and finally we display the solution (english from pairs)
    # ADD SECONDARY SORTING BY LENGTH FROM LESS TO MORE (?)
    distances= distances.sort_by { |k,v| [v['d'], -v['c'].size] }.reverse
    return distances
  end
  
end

class English < ActiveRecord::Base
  establish_connection 'langware_db'
	has_many :pairs
end

class Pair < ActiveRecord::Base
  establish_connection 'langware_db'
	belongs_to :chinese
	belongs_to :english
	
	RANKING={"x" => 100, "g" => 20, "c" => 10, "u" => 5}
  LIMIT_RECS = 500
  
  ###########################################################################
  
  #            USE STANDARIZE FOR THE NORMAL QUERY TO DB TOO                #
  
  ###########################################################################
  def self.standarize_sources(arr) 
    sources, other= [], 0
    arr.each do |s1|
      if %w[x xe xmt g c u w].include?(s1) # CHECK WHICH ONES EXIST!!!
        sources << s1
      else
        other +=1
      end
    end
    sources = sources.sort.join()
    if other>0
      sources << "+" if sources != ""
      sources << "#{other}"
    end
    return sources
  end
  ###########################################################################
  
  #            USE STANDARIZE FOR THE NORMAL QUERY TO DB TOO                #
  
  ###########################################################################
	
	def self.chain_condis(hash)
    chain, params = [], {}
    hash.each do |k,v|
      case k
        when :chinese_id
          chain << "chinese_id = :cid"
          params[:cid]=v
        when :english_id
          chain << "english_id = :eid"
          params[:eid]=v
        when :status
          chain << "status IN (:sts)"
          params[:sts]=v
        when :sources
          chain << "source && :src"
          params[:src]=v.pg
        when :updated_at
          chain << "updated_at >= :tmsp"
          params[:tmsp]=v
      end
    end
    [chain.join(" AND "), params]
  end
  
  def self.get_pairs(args)
    if args[:chinese_id]==-1 # chinese string filled in but not in db
        []
    else
      a,b= chain_condis(args)
      #puts a; ap b
      Pair.where(a, b, :order=>'updated_at DESC').limit(LIMIT_RECS)
    end
  end
  
  def self.organize_pairs(pall)
    pairs = []
    if pall
      pall.each do |p|
        pairs<< {
          :chid => p[:chinese_id],
          :chit => p.chinese.term,
          :eid  => p[:english_id], 
          :engt => p.english.term,
          :sts  => p.status, 
          :src  => p[:source].sort.reverse.join(", "),
          #:rkg  => p[:source].inject(0){|tot, s| tot += (RANKING[s] ? RANKING[s] : 1)}
          :gfreq=> p.english.gfreq
        }
      end
    end
    return pairs
  end
	
	def self.retrieve(conditions)
	  pairs = []
    if !conditions[:english_id] and conditions[:english_term]
      eng = conditions.delete(:english_term)
      if eng.match(/^%|%$/)
        stop = false
        max = (English.where("term LIKE ?", eng).count/LIMIT_RECS).floor+1
        (0...max).each do |i|
          break if stop
          eall = English.where("term LIKE :et", {:et => eng}).limit(LIMIT_RECS).offset(LIMIT_RECS*i)
          eall.each do |e|
            if pairs.size >= LIMIT_RECS
              stop = true
              break
            else
              conditions[:english_id] = e.id
              pairs += organize_pairs(get_pairs(conditions))
            end
          end
        end
        return pairs
      else
        if e = English.find_by_term(eng)
          conditions[:english_id] = e.id 
        end
      end
    end
    if !conditions[:chinese_id] and conditions[:chinese_term]
      chi = conditions.delete(:chinese_term)
      if chi.match(/^%|%$/)
        stop = false
        max = (Chinese.where("term LIKE ?", chi).count/LIMIT_RECS).floor+1
        (0...max).each do |i|
          break if stop
          call = Chinese.where("term LIKE :ct", {:ct => chi}).limit(LIMIT_RECS).offset(LIMIT_RECS*i)
          call.each do |c|
            if pairs.size >= LIMIT_RECS
              stop = true
              break
            else
              conditions[:chinese_id] = c.id
              pairs += organize_pairs(get_pairs(conditions))
            end
          end
        end
        return pairs
      else
        conditions[:chinese_id] = (c=Chinese.find_by_term(chi)) ? c.id : -1
      end
    end

    pairs += organize_pairs(get_pairs(conditions))
    pairs
  end
  
  def self.reorder(params, new_list)
    i=0
    new_list.each do |e|
      if e= English.find_by_term(e)
        params[:english_id]=e.id
        if p=Pair.first(:conditions=>params)
          i+=1
          puts "#{e.term} => rank #{p.rank} becomes #{i}"
          p.rank = i
          unless p.save
            raise "could not update pair with new rank"
            return 500
          end
        else
          raise "#{e} pair not found"
          status 404
        end
      else
        raise "#{e} english not found"
        status 404
      end
    end
    return 200
  end
  
  def self.kill(params)
    if p= Pair.first(:conditions=>params)
      Trash.where(:cterm => p.chinese.term, :eterm => p.english.term).first_or_create
      p.delete
      return 200
    else
      raise "Pair not found"
      return 404
    end
  end
  
  def self.verify(params)
    if p= Pair.first(:conditions=>params)
      p.status = 'v'
      if p.save
        return 200
      else
        raise "could not update pair with new status"
        return 500
      end
    end
    raise "Pair not found"
    return 404
  end
  
  def self.edit_english(params)
    chinese = Chinese.find(params[:chinese_id])
    old_eng = English.find(params[:english_id])
    old_pair = Pair.first(:conditions=>{:chinese_id=>chinese.id, :english_id=>old_eng.id})
    new_eng = English.where(:term => params[:new_eng]).first

    if new_eng==nil # new english term does not exist in English Table
      Trash.where(:cterm => chinese.term, :eterm => old_eng.term).first_or_create
      if Pair.where(:english_id => old_eng.id).count!=1
        puts "#{params[:new_eng]} doesnt exist, n pairs => creating new one and rewiring..."
        new_eng = English.create(:term => params[:new_eng])
        Pair.create(:chinese_id=> chinese.id, :english_id=> new_eng.id, 
                    :status=> "v", :source=> ["xe"], :rank=> old_pair.rank)
        old_pair.destroy
      else
        puts "#{params[:new_eng]} does not exist, 1 pair => updating directly..."
        old_eng.term= params[:new_eng]
        old_eng.save
        old_pair.status = "v"
        old_pair.source << "xe" unless old_pair.source.include?("xe")
        old_pair.save
      end
    else
      if new_eng.id==old_eng.id
        puts "same as before, dont do anything"
        return 304
      else
        puts "#{params[:new_eng]} already exist, rewiring pair..."
        Trash.where(:cterm => chinese.term, :eterm => old_eng.term).first_or_create
        old_pair.destroy
        
        if new_pair = Pair.first(:conditions=>{:chinese_id=>chinese.id, :english_id=>new_eng.id})
          puts "... and since the new pairing already exists, no need to do anything"
        else
          Pair.create(:chinese_id=> chinese.id, :english_id=> new_eng.id, 
                      :status=> "v", :source=> ["xe"], :rank=> old_pair.rank)
          puts "... and created new pairing with v and xe"
        end
      end
    end
    return 200
  end
  
  def self.add(params)
    begin
      c = Chinese.find_or_create_by_term(params["chinese_term"])
      e = English.find_or_create_by_term(params["english_term"])
      
      conditions= {:chinese_id=>c.id, :status=>['v','c']}
      new_list= Pair.all(:conditions=>conditions, :order=>:rank).map{|p2| p2.english.term}
      
      if p=Pair.where(:chinese_id=> c.id, :english_id=> e.id).first
        p.status= "v"
        p.source << params["source"] unless p.source.include?(params["source"])
        p.save
        return 200
      else
        Pair.create(:chinese_id=> c.id, :english_id=> e.id, :status=>'v', 
          :source=> [params["source"]].pg, :rank=> 1)
        new_list.unshift(params["english_term"])
        return Pair.reorder(conditions, new_list)
      end
    rescue
      raise "Unable to Add Pair to DB"
      return 500
    end
  end
  
  def self.queryDB(terms)
    gloss = {}
    terms.compact.uniq.each do |t|
      if c = Chinese.find_by_term(t)
        c.pairs.all(:conditions => {:status => ["c", "v"]}, :order=> "rank").each do |p|  
          sources = []
          other = 0
          p.source.each do |s1|
            if %w[x xe xmt g c u w].include?(s1)
              sources << s1
            else
              other +=1
            end
          end
          sources = sources.sort.join()
          if other>0
            sources << "+" if sources != ""
            sources << "#{other}"
          end
          
          element = [p.english[:term], sources, p.status=="v"]
          gloss[t] ? (gloss[t] << element) : (gloss[t] = [element])
        end
      end
    end
    
    return gloss
  end
  
  # ACCES GLOSSARY ALONE (based on Termlink) #
  MAX_HITS = 3
  
  def self.longest_chi(chistring, source_lan)
    hits, sol = 0, []
    line_arr = chistring.scan(/./)
    while (line_arr.size>0 && hits<MAX_HITS) 
      unless line_arr.size==1 && hits!=0  # special case: only show unigram if nothing else available
        if source_lan=="ct"
            if c = Chinese.find_by_term(line_arr.join)
              hits += 1
              sol << c
            end
        elsif source_lan == "ch" 
            if c = Chinese.find(:first, :conditions => {:simplified => line_arr.join})
              hits += 1
              sol << c
            end
        end
      end
      line_arr.pop
    end
    sol.uniq
  end
  
  def self.retrieve_pairs_by_chinese(chistring, source_lan)
    sol = {}
    chineses = longest_chi(chistring, source_lan)
    chineses.each do |c|
      pairs = []
      c.pairs.all(:order=> "rank").each do |p|  
      #c.pairs.all(:conditions => {:status => ["c", "v"]}, :order=> "rank").each do |p|  
      #c.pairs.each do |p|
        pairs<< {
          :engt => p.english.term,
          #:sts => color_status(p.status), 
          :sts => ((p.status=="r" || p.status=="q" || p.status=="g") ? "rq" : p.status),
          #:src => rank_by_source(p.source)}
          :src => standarize_sources(p.source)}
      end
      key = source_lan=="ct" ? c.term : c.simplified
      #sol[key] = sort_by_goodness(pairs) # NOT NEEDED, already ranked by rank
      sol[key] = pairs
    end
    sol.empty? ? {chistring=> [{:engt => "no results found", :sts => "xx"}]} : sol
  end
  
end


class Trash < ActiveRecord::Base
  establish_connection 'langware_db'
end

class Users < ActiveRecord::Base
  establish_connection 'langware_db'
end


class Constant < ActiveRecord::Base
  establish_connection 'langware_db'
end
class CCFile < ActiveRecord::Base
  establish_connection 'langware_db'
end
class Frequency < ActiveRecord::Base
  establish_connection 'langware_db'
end
class SuffixBreaker < ActiveRecord::Base
  establish_connection 'langware_db'
end
class PredefinedBreaker < ActiveRecord::Base
  establish_connection 'langware_db'
end
class Preparse < ActiveRecord::Base
  establish_connection 'langware_db'
end

class Parserule < ActiveRecord::Base
  establish_connection 'langware_db'
end




#require 'data_mapper'
#
#class Constant
#  include DataMapper::Resource
#	
#	property :name,     Text, :key => true, :unique => true
#  property :content,  Text
#end
#
#class CCFile
#  include DataMapper::Resource
#	
#	property :binomial,   Text, :key => true, :unique => true, :index => true
#	property :meta,       Text
#  property :regexp,     Text
#end
#
#class Frequency
#  include DataMapper::Resource
#	
#	property :term,     Text, :key => true, :unique => true, :index => true
#  property :freq,     Integer
#  property :count,    Integer
#  property :adjusted, Integer
#end
#
#class SuffixBreaker
#  include DataMapper::Resource
#	
#	property :term,     Text, :key => true, :unique => true, :index => true
#  property :poscats,  Text
#end
#
#class PredefinedBreaker
#  include DataMapper::Resource
#	
#	property :term,   Text, :key => true, :unique => true, :index => true
#  property :sub1,   Text
#  property :sub2,   Text
#end
#
#class Preparse
#  include DataMapper::Resource
#  property :term,   Text, :key => true, :unique => true, :index => true
#end

# THE PREVIOUS SQLITE3 MODEL
#require 'data_mapper'
#
#class Translator
#  include DataMapper::Resource
#	property :name,     Text, :key => true, :unique => true  
#end
#class Chinese
#	include DataMapper::Resource
#	has n, :pairs
#	property :id,       Serial, :key => true
#  property :term,     Text,   :unique => true
#  property :simplified,   Text
#end
#class Pos
#  include DataMapper::Resource
#  has n, :english
#  property :val,      String, :key => true
#end
#class English
#	include DataMapper::Resource
#	has n, :pairs
#	belongs_to :pos
#	property :id,       Serial, :key => true
#  property :term,     Text, :unique => [:pos_val]   ######### IS THIS WORKING??
#  property :pos_val,  String
#  property :domain,   Json
#	property :alt,	    Text
#	property :root,	    String
#	property :assoc,	  Json
#	property :nfreq,    Integer
#end
#class Trash
#  include DataMapper::Resource
#	property :chiterm,     Text, :key => true
#	property :engterm,     Text, :key => true
#end
#class Status
#	include DataMapper::Resource
#	has n, :pairs
#	property :val,       String, :key => true
#end
#class Pair
#	include DataMapper::Resource
#	has n, :clients, :through => Resource#, :constraint => :destroy
#	has n, :sources, :through => Resource#, :constraint => :destroy
#	belongs_to :chinese
#	belongs_to :english
#	property :chinese_id,   Integer,  :key => true
#	property :english_id,   Integer,  :key => true
#	property :restat,   Integer
#	belongs_to :status
#	property :status_val,   String, :default => "r", :index => true # ADDED INDEX
#	property :note,     Text
#	property :date,     Date, :default => Time.now
#end
#class Client
#	include DataMapper::Resource
#	has n, :pairs, :through => Resource
#	property :val,       String, :key => true
#end
#class ClientPair
#  include DataMapper::Resource
#  property :pair_chinese_id,    Integer,  :key => true
#  property :pair_english_id,    Integer,  :key => true
#  property :client_val,         String,   :key => true
#  belongs_to :client
#  belongs_to :pair
#end
#class Source
#	include DataMapper::Resource
#	has n, :pairs, :through => Resource
#	property :val,       String, :key => true
#end
#class PairSource
#  include DataMapper::Resource
#  property :pair_chinese_id,    Integer,   :key => true
#  property :pair_english_id,    Integer,  :key => true
#  property :source_val,         String,   :key => true
#  belongs_to :source
#  belongs_to :pair
#end
#class Country
#	include DataMapper::Resource
#	has n, :pairs, :through => Resource
#	property :val,       String, :key => true
#end
#class CountryPair
#  include DataMapper::Resource
#  property :pair_chinese_id,    Integer,   :key => true
#  property :pair_english_id,    Integer,  :key => true
#  property :country_val,        String,   :key => true
#  belongs_to :country
#  belongs_to :pair
#end


