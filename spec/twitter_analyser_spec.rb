require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'twitter_analyser'
require 'lib/models/community_node'


describe TwitterAnalyser do
  describe "communities detection" do
    before(:each) do
      @users = (0..5).map { User.create }

      twitt0 = Twitt.create(:id => "Twitt-00", :user => @users[0])
      twitt1 = Twitt.create(:id => "Twitt-10", :user => @users[1])
      twitt0.parent = twitt1
      twitt0.save
      twitt0 = Twitt.create(:id => "Twitt-01", :user => @users[1])
      twitt1 = Twitt.create(:id => "Twitt-11", :user => @users[0])
      twitt0.parent = twitt1
      twitt0.save

      twitt2 = Twitt.create(:id => "Twitt-20", :user => @users[0])
      twitt3 = Twitt.create(:id => "Twitt-30", :user => @users[2])
      twitt2.parent = twitt3
      twitt2.save
      twitt2 = Twitt.create(:id => "Twitt-21", :user => @users[2])
      twitt3 = Twitt.create(:id => "Twitt-31", :user => @users[0])
      twitt2.parent = twitt3
      twitt2.save

      twitt4 = Twitt.create(:id => "Twitt-40", :user => @users[1])
      twitt5 = Twitt.create(:id => "Twitt-50", :user => @users[4])
      twitt4.parent = twitt5
      twitt4.save
      twitt4 = Twitt.create(:id => "Twitt-41", :user => @users[4])
      twitt5 = Twitt.create(:id => "Twitt-51", :user => @users[1])
      twitt4.parent = twitt5
      twitt4.save

      twitt6 = Twitt.create(:id => "Twitt-60", :user => @users[3])
      twitt7 = Twitt.create(:id => "Twitt-70", :user => @users[4])
      twitt6.parent = twitt7
      twitt6.save
      twitt6 = Twitt.create(:id => "Twitt-61", :user => @users[4])
      twitt7 = Twitt.create(:id => "Twitt-71", :user => @users[3])
      twitt6.parent = twitt7
      twitt6.save

      twitt8 = Twitt.create(:id => "Twitt-80", :user => @users[5])
      twitt9 = Twitt.create(:id => "Twitt-90", :user => @users[4])
      twitt8.parent = twitt9
      twitt8.save
      twitt8 = Twitt.create(:id => "Twitt-81", :user => @users[4])
      twitt9 = Twitt.create(:id => "Twitt-91", :user => @users[5])
      twitt8.parent = twitt9
      twitt8.save

      @twitter_analyser = TwitterAnalyser.new
      @community_graph = @twitter_analyser.detect_communities!(:weak_community)
    end

    describe "detect communities" do
      it "should detect twitter communities and store them to database" do
        expected_community1 = Set.new([5, 6, 4])
        expected_community2 = Set.new([1, 2, 3])

        @community_graph.subgraphs.map { |s| Set.new(s.nodes.keys) }.should == [expected_community1, expected_community2]

        Community.first(:id => 1).parent_id.should == nil
        community1 = Community.first(:id => 2)
        community1.parent_id.should == 1
        community2 = Community.first(:id => 3)
        community2.parent_id.should == 1

        Set.new(community1.users.map { |u| u.id }).should == expected_community1
        Set.new(community2.users.map { |u| u.id }).should == expected_community2
      end
    end

    describe "analize" do
      before(:each) do
        UserFollower.create(:user => @users[0], :follower => @users[1])
        UserFollower.create(:user => @users[2], :follower => @users[0])
        UserFollower.create(:user => @users[0], :follower => @users[4])
      end

      it "should compute page ranks of all nodes and save it to database" do
        @twitter_analyser.compute_page_ranks!
        User.all? { |u| u.page_rank != nil }.should be_true
      end

      it "should find edges of detected communities properly" do
        community = Community.first(:parent_id => nil)
        community_node = CommunityNode.new(community.id, community.users.count, community.strength, community.density)
        community_edges = TwitterAnalyser.find_edges(community_node)
        community_edges.size.should == 2
        community_edges.should include([CommunityNode.new(1, 6, nil, nil), CommunityNode.new(2, 3, nil, nil)])
        community_edges.should include([CommunityNode.new(1, 6, nil, nil), CommunityNode.new(3, 3, nil, nil)])
      end

      it "should compute user follower dependencies % in communities" do
        community_id = 3
        TwitterAnalyser.followers_percent(community_id).should == 3.0/4
      end

      it "should draw dendrogram properly" do
        lambda { TwitterAnalyser.draw_dendrogram('test') }.should_not raise_error
      end

      it "should draw followers statistics properly" do
        lambda { TwitterAnalyser.draw_followers_statistics("test") }.should_not raise_error
      end

      it "should draw page ranks statistics properly" do
        @twitter_analyser.compute_page_ranks!
        lambda { TwitterAnalyser.draw_page_ranks_statistics("test") }.should_not raise_error
      end
    end
  end
  
  describe "compute statistics" do
    it "should compute page ranks statistics properly" do
      TwitterAnalyser.stub!(:page_ranks).and_return([1, 2, 7])
      TwitterAnalyser.page_ranks_min(nil).should == 1
      TwitterAnalyser.page_ranks_max(nil).should == 7
      TwitterAnalyser.page_ranks_avg(nil).should == 3.33
      TwitterAnalyser.page_ranks_standard_deviation(nil).should == 4.55
    end
  end
end

