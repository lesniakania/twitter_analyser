require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'twitter_analyser'

describe TwitterAnalyser do
  before(:each) do
    users = (0..5).map { User.create }

    twitt0 = Twitt.create(:id => "Twitt-00", :user => users[0])
    twitt1 = Twitt.create(:id => "Twitt-10", :user => users[1])
    twitt0.parent = twitt1
    twitt0.save
    twitt0 = Twitt.create(:id => "Twitt-01", :user => users[1])
    twitt1 = Twitt.create(:id => "Twitt-11", :user => users[0])
    twitt0.parent = twitt1
    twitt0.save

    twitt2 = Twitt.create(:id => "Twitt-20", :user => users[0])
    twitt3 = Twitt.create(:id => "Twitt-30", :user => users[2])
    twitt2.parent = twitt3
    twitt2.save
    twitt2 = Twitt.create(:id => "Twitt-21", :user => users[2])
    twitt3 = Twitt.create(:id => "Twitt-31", :user => users[0])
    twitt2.parent = twitt3
    twitt2.save

    twitt4 = Twitt.create(:id => "Twitt-40", :user => users[1])
    twitt5 = Twitt.create(:id => "Twitt-50", :user => users[4])
    twitt4.parent = twitt5
    twitt4.save
    twitt4 = Twitt.create(:id => "Twitt-41", :user => users[4])
    twitt5 = Twitt.create(:id => "Twitt-51", :user => users[1])
    twitt4.parent = twitt5
    twitt4.save

    twitt6 = Twitt.create(:id => "Twitt-60", :user => users[3])
    twitt7 = Twitt.create(:id => "Twitt-70", :user => users[4])
    twitt6.parent = twitt7
    twitt6.save
    twitt6 = Twitt.create(:id => "Twitt-61", :user => users[4])
    twitt7 = Twitt.create(:id => "Twitt-71", :user => users[3])
    twitt6.parent = twitt7
    twitt6.save

    twitt8 = Twitt.create(:id => "Twitt-80", :user => users[5])
    twitt9 = Twitt.create(:id => "Twitt-90", :user => users[4])
    twitt8.parent = twitt9
    twitt8.save
    twitt8 = Twitt.create(:id => "Twitt-81", :user => users[4])
    twitt9 = Twitt.create(:id => "Twitt-91", :user => users[5])
    twitt8.parent = twitt9
    twitt8.save
    
    @twitter_analyser = TwitterAnalyser.new
  end

  describe "detect communities" do
    it "should detect twitter communities and store them to database" do
      expected_community1 = Set.new([5, 6, 4])
      expected_community2 = Set.new([1, 2, 3])
      community_graph = @twitter_analyser.detect_communities
      community_graph.subgraphs.map { |s| Set.new(s.nodes.keys) }.should == [expected_community1, expected_community2]

      Community.first(:id => 1).parent_id.should == nil
      community1 = Community.first(:id => 2)
      community1.parent_id.should == 1
      community2 = Community.first(:id => 3)
      community2.parent_id.should == 1

      Set.new(community1.users.map { |u| u.id }).should == expected_community1
      Set.new(community2.users.map { |u| u.id }).should == expected_community2
    end
  end
end

