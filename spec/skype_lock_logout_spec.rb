require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "SkypeLockLogout" do
  it "should work" do
    sll = Skype_lock_logout.new
    sll.listen
  end
end
