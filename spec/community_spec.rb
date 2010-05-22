require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'models/community'

describe Community do
  before(:each) do
    50.times { Community.create }
  end

  describe "all" do
    it "should retrieve all communities sorted by id" do
      Community.all.should == Community.all.sort { |c1, c2| c1.id <=> c2.id }
    end
  end
end

