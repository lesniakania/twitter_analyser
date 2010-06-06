require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'twitter_analyser'

DIR = File.join('test', 'without_periods')

describe TwitterAnalyser do
  describe "initialize" do
    it "should retrieve twitts from given period time properly" do
      Day = 60*60*24
      Today = Time.now
      users = (0..2).map { User.create }
      twitt0 = Twitt.create(:id => "Twitt-00", :user => users[0], :date => Today)
      twitt1 = Twitt.create(:id => "Twitt-10", :user => users[1], :date => Today+Day)
      twitt1.parent = twitt0
      twitt1.save
      twitt2 = Twitt.create(:id => "Twitt-20", :user => users[2], :date => Today+2*Day)
      twitt2.parent = twitt1
      twitt2.save

      twitt0 = Twitt.create(:id => "Twitt-01", :user => users[0], :date => Today+2*Day)
      twitt1 = Twitt.create(:id => "Twitt-11", :user => users[1], :date => Today+3*Day)
      twitt1.parent = twitt0
      twitt1.save
      twitt2 = Twitt.create(:id => "Twitt-21", :user => users[2], :date => Today+7*Day)
      twitt2.parent = twitt1
      twitt2.save

      t = TwitterAnalyser.new(Today-Day, Today+3*Day)
      Set.new(t.nodes.keys).should == Set.new(users[1..2].map { |u| u.id })
      t.edges.size.should == 1
    end
  end

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
        expected_community1 = Set.new([1, 2, 3])
        expected_community2 = Set.new([5, 6, 4])

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

        @community_graph = @twitter_analyser.detect_communities!(:weak_community)
        TwitterAnalyser.cutoff_communities(Community.root, 90)
      end

      it "should compute page ranks of all nodes and save it to database" do
        TwitterAnalyser.compute_page_ranks!(@community_graph)
        User.filter(:id => @community_graph.nodes.keys).all? { |u| u.page_rank != nil }.should be_true
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
        community_id = 2
        TwitterAnalyser.followers_percent(community_id).should == 3.0/4
      end

      it "should draw dendrogram properly" do
        lambda { TwitterAnalyser.draw_dendrogram(DIR) }.should_not raise_error
      end

      it "should draw followers statistics properly" do
        lambda { TwitterAnalyser.draw_followers_statistics(DIR) }.should_not raise_error
      end

      it "should draw page ranks statistics properly" do
        TwitterAnalyser.compute_page_ranks!(@community_graph)
        lambda { TwitterAnalyser.draw_page_ranks_statistics(DIR) }.should_not raise_error
      end
    end
  end

  describe "cutoff" do
    it "should cutoff cummunities properly" do
      root = Community.create(:strength => 0)
      parent = Community.create(:parent => root, :strength => 66)
      Community.create(:parent => root, :strength => 77)
      communities = [
        Community.create(:parent => parent, :strength => 45),
        Community.create(:parent => parent, :strength => 40),
        Community.create(:parent => parent, :strength => 35)
      ]
      TwitterAnalyser.cutoff_communities(Community.root, 50)
      Community.filter(:cutoff => true).map { |c| c.id }.sort.should == communities.map { |c| c.id }.sort
    end
  end

  describe "compute statistics" do
    it "should compute page ranks statistics properly" do
      TwitterAnalyser.stub!(:page_ranks).and_return([[1, ''], [2, ''], [7, '']])
      TwitterAnalyser.page_ranks_min(nil)[:page_rank].should == 1
      TwitterAnalyser.page_ranks_max(nil)[:page_rank].should == 7
      TwitterAnalyser.page_ranks_avg(nil).should == 3.33
      TwitterAnalyser.page_ranks_standard_deviation(nil).should == 4.55
    end

    describe "sequences" do
      before(:each) do
        @root = Community.create
        @c1 = Community.create(:parent => @root, :cutoff => true)
        @c2 = Community.create(:parent => @root, :cutoff => true)
        users = 4.times.map { User.create }
        users.each { |u| @root.add_user(u) }
        users[1..2].each { |u| @c1.add_user(u) }
        @key1 = users.map { |u| u.id }.join('-')
        @key2 = users[1..2].map { |u| u.id }.join('-')
        SequenceFreq.create(:key => @key1)
        SequenceFreq.create(:key => @key2)
      end

      it "should compute percent of sequences per community" do
        TwitterAnalyser.sequence_percent(@root).should == 100
        TwitterAnalyser.sequence_percent(@c1).should == 50
        TwitterAnalyser.sequence_percent(@c2).should == 0
        TwitterAnalyser.draw_sequences_percent_statistics(DIR)
      end

      it "should compute group members count for most frequent sequences" do
        TwitterAnalyser.frequent_sequences_group_counts.should == [[@key1, 4], [@key2, 2]]
        TwitterAnalyser.draw_frequent_sequences_statistics(DIR)
      end
    end

    describe "dynamics" do
      it "should draw dynamics statistics properly" do
        [1,2,3].each do |number|
          communities = [0..2].map { Community.create(:cutoff => true) }
          communities.each do |community|
            community.id.times do
              community.add_user(User.create)
              community.save
              Log.create(:community_id => community.id, :number => number, :users_count => community.users.count)
            end
          end
        end
        TwitterAnalyser.draw_dynamics_statistics(DIR)
      end

      it "should compute dynamics stats properly" do
        Log.create(
            :number => 1, :community_id => 777,
            :community_definition => TwitterAnalyser::COMMUNITY_DEFINITIONS[:strong_community]
        )

        logs1 = (1..3).map { |i| Log.create(
            :number => 1, :community_id => i,
            :community_definition => TwitterAnalyser::COMMUNITY_DEFINITIONS[:weak_community]) }
        (1..3).each { |i| logs1[0].add_log_user(LogUser.create(:user_id => i)) }
        (4..11).each { |i| logs1[1].add_log_user(LogUser.create(:user_id => i)) }
        (12..16).each { |i| logs1[2].add_log_user(LogUser.create(:user_id => i)) }
        
        logs2 = (1..2).map { |i| Log.create(
            :number => 2, :community_id => i,
            :community_definition => TwitterAnalyser::COMMUNITY_DEFINITIONS[:weak_community]) }
        (1..2).each { |i| logs2[0].add_log_user(LogUser.create(:user_id => i)) }
        (5..7).each { |i| logs2[0].add_log_user(LogUser.create(:user_id => i)) }
        (12..16).each { |i| logs2[1].add_log_user(LogUser.create(:user_id => i)) }
        (17..18).each { |i| logs2[1].add_log_user(LogUser.create(:user_id => i)) }

        dynamics = TwitterAnalyser.dynamics_stat(logs1[0])
        dynamics.users_count.should == 3
        dynamics.next_communities_mapping.should == { logs2[0].id => 2, logs2[1].id => 0 }
        dynamics.rejected_users_count.should == 1
        dynamics.new_users_count.should == 3

        dynamics = TwitterAnalyser.dynamics_stat(logs1[1])
        dynamics.users_count.should == 8
        dynamics.next_communities_mapping.should == { logs2[0].id => 3, logs2[1].id => 0 }
        dynamics.rejected_users_count.should == 5
        dynamics.new_users_count.should == 8

        dynamics = TwitterAnalyser.dynamics_stat(logs1[2])
        dynamics.users_count.should == 5
        dynamics.next_communities_mapping.should == { logs2[0].id => 0, logs2[1].id => 5 }
        dynamics.rejected_users_count.should == 0
        dynamics.new_users_count.should == 5


        dynamics = TwitterAnalyser.dynamics_stat(logs2[0])
        dynamics.users_count.should == 5
        dynamics.next_communities_mapping.should == {}
        dynamics.rejected_users_count.should == 5
        dynamics.new_users_count.should == 0

        dynamics = TwitterAnalyser.dynamics_stat(logs2[1])
        dynamics.users_count.should == 7
        dynamics.next_communities_mapping.should == {}
        dynamics.rejected_users_count.should == 7
        dynamics.new_users_count.should == 2
      end
    end
  end
end

