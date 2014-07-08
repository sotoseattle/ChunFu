require './lib/kungfu/ZhEng_Calc'

Given /^the original chinese number is "([^"]*)"$/ do |e|
  @x = ZhEng_Calc.new(e)
end



When /^we standardize it$/ do
  @x.standardize
end

When /^we precompute it$/ do
  @x.standardize
  r= @x.root_node
  r.content= {"in"=>@x.numb, "out"=>nil, "m"=>nil}
  @x.numb= @x.compute_number(@x.numb, r)
end

When /^we translate it$/ do
  @x.translate
end



Then /^the number in standard form is "(.*?)"$/ do |std|
  @x.numb.should == std
end

Then /^the number in precomputed form is "(.*?)"$/ do |prc|
  (@x.numb.to_f - prc.to_f).should be < 1e-10
end

Then /^it should show as "(.*?)"$/ do |eng|
  @x.numb.should == eng
end
