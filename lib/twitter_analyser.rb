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
      self.nodes[u.id] = Node.new(u.id) if u.twitts.any? { |t| t.parent && User.filter(:id => t.parent.user.id) }
    end
    self.edges = []
    Twitt.filter(~{:parent_id => nil}).all.each_with_index do |twitt, i|
      edge = [self.nodes[twitt.user.id], self.nodes[twitt.parent.user.id]]
      self.edges << Edge.new(*edge) if edge.none? { |o| o.nil? }
    end
    self.graph = Graph.new(self.nodes.values, self.edges)
    puts "Graph has #{graph.nodes.size} nodes."
    puts "And #{graph.edges.size} edges."
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

  def self.draw_dendrogram
    community = Community.first(:parent_id => nil)
    community_node = CommunityNode.new(community.id, 0)
    community_edges = find_edges(community_node)

    dg = RGL::DirectedAdjacencyGraph.new
    community_edges.each { |e| dg.add_edge(e[0], e[1]) }
    dg.write_to_graphic_file('png', './images/dendrogram')
    `rm -rf images/*.dot`
  end

  def self.find_edges(community_node)
    community_edges = []
    children = []
    Community.filter(:parent_id => community_node.id).each do |subcommunity|
      child = CommunityNode.new(subcommunity.id, subcommunity.users.count)
      children << child
      community_edges += [[community_node, child]] + find_edges(subcommunity)
    end
    children.each do |subcommunity|
      community_node.size += subcommunity.size
    end
    community_edges
  end
end

class CommunityNode
  attr_accessor :id, :size

  def initialize(id, size)
    self.id = id
    self.size = size
  end

  def to_s
    "#{id} (#{size})"
  end
end
