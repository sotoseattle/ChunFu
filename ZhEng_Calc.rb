# encoding: utf-8
require 'rubygems'
require 'bigdecimal'
require 'tree'
#require 'awesome_print'

XTN_Standardize = [["[○〇Ｏ零]", '0'], ["[１一壹幺]", '1'], ["[２二兩貳两贰]", '2'], ["[３三參叁叄]", '3'], ["[４四肆]", '4'], 
  ["[５五伍]", '5'], ["[６六陸陆]", '6'], ["[７七柒]", '7'], ["[８八捌]", '8'], ["[９九玖]", '9'], 
  ["[拾呀]", '十'], ["佰", '百'], ["仟", '千'],['億', '亿'], ['萬', "万"],["[廿念]", '2十'],["卅", '3十'], ["卌", '4十'], ["皕", '2百'],
  ["[點点]", '\\.'], ["、", ','], ["[負负]", '-'], ["(\\d)[ ]?,[ ]?(\\d\\d\\d)", '#{$2}#{$3}']]
  
XT_Multipliers= {"京"=>10**16, "兆"=>10**12, "亿"=>10**8, "万"=>10**4, "千"=>1000, "百"=>100, "十"=>10}

XTN_Formats = [[6, 100, "million"], [9, 100, "billion"], [12, 1000, "trillion"]]
  
class String
  def numeric?
    Float(self) != nil rescue false
  end
end
  
class ZhEng_Calc
  
  attr_accessor :numb
  attr_reader :tabulous, :root_node
  
  def initialize(str, ver=nil)
    @root_node = Tree::TreeNode.new("x", str)
    @numb= str.strip
    @tabulous = {}
  end
  
  def htmlify(node, show_input=true)
    key= show_input ? "in" : "out"
    
    nota= if node.content["n"]["#{key}"]!=""
      "class='tt' title='"+ node.content["n"]["#{key}"] +"'"
    else
      ""
    end
    
    base= ""
    if key=="out" and node.content["n"]["other"]!=""
      base << node.content["n"]["other"].to_s
    end
    base << node.content["#{key}"].to_s
    
    chi= node.content["m"]
    #base= "<span #{nota}>"+(base=="" ? "NA" : "<span>"+base+"</span>")+"</span>"
    if base==""
      base= "NA"
    elsif nota==""
      base= "<span>"+base+"</span>"
    else
      base= "<span #{nota}><span>"+base+"</span></span>"
    end
    
    
    base.gsub!(chi, "</span><span class='vip'>#{chi}</span><span>") if (show_input and chi)
    base
  end
  
  def draw_tree(node)
    kk = ""
    if node.has_children?
      kk << "<table class='together'><tbody><tr><td colspan='2'>#{htmlify(node, true)}</td></tr><tr>"
      node.children.each{|kid| kk << "<td  class='separate'>"+draw_tree(kid)+"</td>"}
      kk << "</tr><tr><td colspan='2' class='join'>#{htmlify(node, false)}</td></tr></tbody></table>"
    else
      kk << "<table><tbody><tr><td class='single'>#{htmlify(node, true)}</td></tr></tbody></table>"
    end
    kk
  end
  
  def translate
    @tabulous= "<table id='tabulous'><tbody><tr><td id='top'><span class='tt' title='Original form, is first standarized into SC and western digits and punctuation' id='topnumber'>#{@numb}</span></td></tr>"
    standardize
    @root_node.content= {"in"=>@numb, "out"=>nil, "m"=>nil}

    @numb= compute_number(@numb, @root_node)
    
    @tabulous << "<tr><td class='summary'>" + draw_tree(@root_node) + "</td></tr>"
    
    @numb= englishify
    @tabulous << "<tr><td id='bottom' class='summary'><span class='tt' title='English form'>#{@numb}</span></td></tr></tbody></table>"
  end
  
  def standardize
    XTN_Standardize.each do |arr|
      key = Regexp.new(/(#{arr[0]})/)
      cycle = true
      while cycle
        if @numb.match key
          val = eval "lambda {|e| \"#{arr[1]}\" }"        # <== REFACTOR ????
          @numb.sub!(key, &val)
          #puts "Changing #{$1}: #{@numb}"
        else
          cycle = false
        end
      end
    end
    
    if XT_Multipliers.keys.include?(@numb[0])
      @numb.insert(0, "1") 
      #puts "First character is a multiplier character, so we add a 1 to its left: #{@numb}"
    end
  end
  
  def break_by_highest_multiplier(str)
    left, right, multi, chino= nil, nil, nil, nil
    XT_Multipliers.each do |chi, number|
      if str.match(/^(.*)#{chi}(.*)/)
        left, right = $1, $2
        multi= number.to_i
        chino= chi
        break
      end
    end
    return [left, right, multi, chino]
  end
  
  def compute_number(str, node)
    notes= {"in"=>"", "out"=> "", "other"=>""}   ## THE STANDARIZE TEXT SHOWS IN THE BOTTOM ROW!!!
    left, right, multi, chi = break_by_highest_multiplier(str)
    
    child_left=  Tree::TreeNode.new("#{node.name}l", {"in"=>left, "out"=>nil, "m"=>nil, 
      "n"=>{"in"=>"", "out"=> "", "other"=>""}})
    child_right= Tree::TreeNode.new("#{node.name}r", {"in"=>right, "out"=>nil, "m"=>nil,
      "n"=>{"in"=>"", "out"=> "", "other"=>""}})
    
    node << child_left if left
    node << child_right if right
    
    if chi
      notes["in"]<< "we break by the multiplier #{multi}"
    end
    
    unless multi
      sol = str.numeric? ? BigDecimal.new(str) : nil
    else
      if right!=""
        if right.match(/^[1-9][0-9]*$/) && !left.match(/\./) && (chi!="十") # SPECIFIC CASE: Disambiguation of OOs
          total_left = (left=='0' ? 0 : compute_number(left, child_left))
          if total_left==0
            notes["out"] << "nothing to the left, we only calculate the right side"
            sol = BigDecimal.new(right)
          else
            notes["out"] << "left & right become #{total_left.to_i}.#{right.to_i} and then we multiply by factor #{multi}"
            notes["other"]="#{total_left.to_i} [#{chi}] #{right.to_i} => "
            sol= BigDecimal.new("#{total_left.to_i}.#{right.to_i}")*multi
          end
        else
          total_right = compute_number(right, child_right)
          if left=='0'
            temp, total_left = 0, 0
          else
            
            total_left = compute_number(left, child_left)
            if total_left==0
              temp = 1
              total_left= multi
            else
              notes["out"] << "the left part is multiplied by factor [#{total_left.to_f} x #{multi}]"
              temp = BigDecimal.new("#{total_left}")
              total_left= temp*multi
            end
          end
          notes["other"]="[#{temp.to_f} #{chi}] + #{total_right.to_i} => "
          notes["out"] << ", left and right are added [#{total_left.to_f} + #{total_right.to_f}]"
          sol = total_left + total_right
        end
      elsif left!=""  # right is empty
        notes["out"] << "nothing to the right, we only calculate the left side and then multiply by factor #{multi}"
        temp= compute_number(left, child_left)
        sol = BigDecimal.new(temp.to_s)*multi
        notes["other"]<<"[#{temp.to_f} #{chi}] => "
      else
        notes["out"] << "nothing to the left, nor right, the solution is the factor #{multi}"
        sol = multi
      end
    end
    node.content["out"]=sol.to_f.to_s
    node.content["m"]=chi if chi
    node.content["n"]=notes
    return sol
  end
  
  def englishify
    sol= @numb
    if sol
      whole_number = sol#.to_f
      sign = whole_number<0 ? -1 : 1
      whole_number = whole_number.abs
      fractional_part = whole_number.modulo(1)
      above = (whole_number - fractional_part).to_i
      
      if above!=0.0 || fractional_part!=0.0
        if fractional_part==0.0
          sol = commify((above*sign).to_s)      
        
          if above.to_i.to_s.match(/^(.+?)(0{4,})$/)
            XTN_Formats.each do |e|
              kk = above.to_f/10**e[0]
              if (e[1]*kk).modulo(1)==0 && kk>1 && kk<=999.99
                kk = sign*kk
                sol = "#{commify(shrink(kk))} #{e[2]}"
              end
            end
          end
        else
          fractional_part.to_f.to_s.match(/^0\.(.*?)$/)
          sol = "#{commify((above*sign).to_s)}.#{$1}"
        end
      else
        sol= "0, Zero, naught, zilch, nix, zip, nada, diddly-squat"
      end
    else
      sol="n.a."
    end
    return sol
  end
  
  def shrink(number)
    str = "%.3f" % number
    str = str.gsub(/(0*)$/, "").gsub(/(\.)$/, "")
  end
  
  def commify(str)
    str.match(/\d{4,}(\..*)?$/) ?  str.gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2\3') : str
  end
  
end

#an= ZhEng_Calc.new("二百〇五", 1)
#an= ZhEng_Calc.new("一百零五万零五百一", 1)
#an= ZhEng_Calc.new("二百四十零萬一四", 1)
#an= ZhEng_Calc.new("五千八", 1)
#an= ZhEng_Calc.new("十一萬一千一百一十一", true)
#an= ZhEng_Calc.new("一萬兩千三百四十五點六七八九", true)
#an= ZhEng_Calc.new("5.8萬590", 1)
#an.standardize
#an= ZhEng_Calc.new("1.1萬1,111", 1)
#an= ZhEng_Calc.new("十一", 1)
#an= ZhEng_Calc.new("七十四点二五亿", 1)
#an= ZhEng_Calc.new("二百四十零萬一四", 1)
#an.translate
#ap an.numb