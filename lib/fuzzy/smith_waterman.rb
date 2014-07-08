# encoding: utf-8
require 'rubygems'

class Matrix
  
  IndexOverflow = Class.new(StandardError)
  
  attr_reader :dims, :nrows, :ncols
  
  def initialize(mm, nn)
    @dims  = [mm, nn]
    @nrows = mm
    @ncols = nn
    @m     = Array.new(mm)

    (1..mm).each {|i| @m[i-1] = Array.new(nn, 0)}
  end
  
  def inspect
    @m.inject("") do |str, row|
      str +=  row.collect {|v| sprintf("%5d", v)}.join(" ") + "\n"
    end
  end  

  def [](i, j)    
    raise IndexOverflow if ((i >= nrows) || (j >= ncols))
    
    @m[i][j]
  end
  
  def []=(i, j, k)
    raise IndexOverflow if ((i >= nrows) || (j >= ncols))

    @m[i][j] = k
  end
end

class StringAlign

  #SCORE_INSERT =  0; SCORE_DELETE =  -1; SCORE_MISS   = -1
  SCORE_INSERT =  -1
  SCORE_DELETE =  -1
  SCORE_MISS   = -1
  SCORE_MATCH  =  2

  attr_reader :str_a, :str_b, :str_a_arr, :str_b_arr, :m, :n, :mat, :config, :alignment, :score

  def initialize(stra, strb, opts = {})
    @str_a  = stra
    @str_b  = strb
    
    @str_a_arr = stra.split("")
    @str_b_arr = strb.split("")
    
    @m      = str_a.length + 1
    @n      = str_b.length + 1
    @mat    = Matrix.new(m, n)
    
    @config = opts
  end

  def align!
    iterate_over_cells!
    find_optimal_path
    
    return alignment
  end
  
  def alignment_inspect
    la, lb = "... ", "... "
  
    alignment.each_with_index do |pos, i|
      next if (i == 0)
      case alignment[i-1][2]
        when :down
          la += [ str_a_arr[pos[0]-1] ].join
          lb += "-"
        when :right
          la += "-"
          lb += [ str_b_arr[pos[1]-1] ].join
        else
          la += [ str_a_arr[pos[0]-1] ].join
          lb += [ str_b_arr[pos[1]-1] ].join
      end
    end
  
    "#{la} ...\n#{lb} ..."    
  end
    
  private
  
  def find_optimal_path    
    @alignment = []    
    recurse_optimal_path(@i_max, @j_max)

    @alignment.reverse!
    @alignment.each_with_index do |pos, i|
      next_pos = alignment[i+1]
      next if next_pos.nil?

      del_i = next_pos[0] - pos[0]
      del_j = next_pos[1] - pos[1]
      direction = case (del_i + del_j)
        when 2 then :diagonal
        when 1 then (del_i > del_j) ? :down : :right
      end

      pos << direction
    end
  end

  def recurse_optimal_path(i_curr, j_curr)    
    @alignment << [i_curr, j_curr]
    
    values = [
      mat[i_curr-1, j_curr-1],
      mat[i_curr-1, j_curr],
      mat[i_curr  , j_curr-1]
    ]
    
    ii, jj = case values.index(values.max)
      when 0 then [i_curr-1, j_curr-1]
      when 1 then [i_curr-1, j_curr]
      when 2 then [i_curr  , j_curr-1]
    end    
    
    if (mat[i_curr, j_curr] == 0)
      return
    else
      return recurse_optimal_path(ii, jj)
    end
  end
  
  def iterate_over_cells!
    @score = -1
    @i_max, @j_max = 0, 0
    (2..m).each do |i|
      (2..n).each do |j|
        assign_cell(i-1, j-1)
      end
    end
  end
  
  def assign_cell(i, j)
    score = (str_a_arr[i-1] == str_b_arr[j-1]) ? SCORE_MATCH : SCORE_MISS      

    value = [0,
      mat[i-1, j-1] + score,
      mat[i-1, j] + SCORE_DELETE,
      mat[i, j-1] + SCORE_INSERT      
    ].max
    
    if (value >= @score)
      @score = value
      @i_max = i
      @j_max = j
    end
    
    mat[i,j] = value
  end
  
end

#sa = StringAlign.new("頸動脈的", "主動脈前的")
#sa = StringAlign.new("ABCD","ABCD")

#sa.align!
##puts sa.mat.inspect

##puts sa.alignment.inspect
#puts "SCORE = #{sa.score}"