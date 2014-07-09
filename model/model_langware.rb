# -*- coding: utf-8 -*-

class Chinese < ActiveRecord::Base
  establish_connection 'langware_db'
	has_many :pairs
	
  def self.fuzzysearch(chist, app)
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
          sol= (pos==0 ? app.settings.mandarinos[array_chars[0]] : (sol & app.settings.mandarinos[cc]))
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
	
  # ACCES GLOSSARY ALONE (based on Termlink) #
  def self.retrieve_pairs_by_chinese(chistring, source_lan)
    sol = {}
    c = if source_lan=="ct"
      Chinese.find_by_term(chistring)
    elsif source_lan == "ch" 
      Chinese.find(:first, :conditions => {:simplified => chistring})
    end

    if c
      pairs = []
      c.pairs.all(:order=> "rank").each do |p|  
        pairs<< {
          :engt => p.english.term,
          :sts => ((p.status=="r" || p.status=="q" || p.status=="g") ? "rq" : p.status)}
      end
      key = source_lan=="ct" ? c.term : c.simplified
      sol[key] = pairs
    else
      sol= {chistring=> [{:engt => "no results found", :sts => "xx"}]}
    end
    return sol
  end
  
  
  def self.deconstruct_chinese(chistring)
    sol= {}
    chistarr= chistring.split("")
    len= chistring.size
    if len > 1
      (1...len).each do |i|
        (0..i).each do |n|
          ngram_size= len-i
          if c= Chinese.find_by_term(chistarr[n,ngram_size].join)
            pairs = []
            c.pairs.all(:order=> "rank").each do |p|  
              pairs<< {
                :engt => p.english.term,
                :sts => ((p.status=="r" || p.status=="q" || p.status=="g") ? "rq" : p.status)}
              end
            if !sol[:"#{c.term}"]
              sol[:"#{c.term}"] = pairs
            else
              sol[:"#{c.term}"] << pairs
            end
          end
        end
      end
    end
    return sol
  end
 
end
