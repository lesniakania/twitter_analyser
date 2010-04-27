require 'lib/models/twitt'
require 'lib/models/user'
require 'lib/models/user_follower'
require 'lib/models/community'
require 'social_network_analyser'
require 'graph'
require 'node'
require 'edge'

class TwitterAnalyser
  attr_accessor :graph, :nodes, :edges

  def initialize
    puts 'Init started...'
    self.nodes = {}
    User.each do |u|
      self.nodes[u.id] = Node.new(u.id)
    end
    self.edges = []
    Twitt.filter(~{:parent_id => nil}).all.each_with_index do |twitt, i|
      self.edges << Edge.new(self.nodes[twitt.user.id], self.nodes[twitt.parent.user.id])
    end
    self.graph = Graph.new(self.nodes.values, self.edges)
    puts 'Init finished.'
  end

  def detect_communities
    puts 'Detecting communities...'
    communities_graph = SocialNetworkAnalyser.detect_communities(self.graph, :weak_community)
    puts 'Detecting communities finished.'
    puts 'Saving to database...'
    self.save_all_communities(communities_graph)
    puts 'Saved.'
    communities_graph
  end

  def save_all_communities(graph)
    root_community = Community.create
    self.save_communities(graph, root_community)
  end

  def save_communities(graph, community)
    if graph.nodes.empty? && !graph.subgraphs.empty?
      graph.subgraphs.each do |s|
        subcommunity = Community.create(:parent => community)
        save_communities(s, subcommunity)
      end
    else
      User.filter(:id => graph.nodes.keys).update(:community_id => community.id)
    end
  end
end
