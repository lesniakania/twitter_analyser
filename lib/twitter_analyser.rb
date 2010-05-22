require 'lib/extensions'
require 'lib/models/twitt'
require 'lib/models/user'
require 'lib/models/user_follower'
require 'lib/models/community'
require 'lib/models/community_node'
require 'social_network_analyser'
require 'graph'
require 'node'
require 'edge'

class TwitterAnalyser
  attr_accessor :graph, :nodes, :edges

  def initialize
    puts 'Init started...'
    self.nodes = {}
    User.order(:id).limit(100).each do |u|
    #User.order(:id).limit(6000).each do |u|
    #User.each do |u|
      self.nodes[u.id] = Node.new(u.id) if u.twitts.any? { |t| t.parent && t.parent.user_id }
    end
    puts 'Users processed...'
    self.edges = []
    Twitt.filter('twitts.parent_id is not null').eager_graph(:parent).each do |set|
      edge = [self.nodes[set[:twitts].user_id], self.nodes[set[:parent].user_id]]
      self.edges << Edge.new(*edge) if edge.none? { |o| o.nil? }
    end
    puts 'Twitts processed...'
    self.graph = Graph.new(self.nodes.values, self.edges)
    puts "Graph has #{self.graph.nodes.size} nodes."
    puts "And #{self.graph.edges.size} edges."
    puts 'Init finished.'
  end

  def detect_communities!(community_definition_sym)
    clear_communities_tables
    puts 'Detecting communities...'
    communities_graph = SocialNetworkAnalyser.detect_communities!(self.graph, community_definition_sym)
    puts 'Detecting communities finished.'
    puts 'Saving to database...'
    self.save_all_communities(communities_graph, nil)
    puts 'Saved.'
    communities_graph
  end

  def compute_page_ranks!(graph)
    # reset
    User.update(:page_rank => nil)
    # compute
    graph.community_nodes.each do |n|
      u = User.first(:id => n.id)
      u.page_rank = SocialNetworkAnalyser.page_rank(graph, n.id)
      u.save
    end
  end

  def self.draw_dendrogram(dir='.')
    community = Community.root
    community_node = CommunityNode.new(community.id, community.users.count, community.strength, community.density)
    community_edges = find_edges(community_node)

    dg = RGL::DirectedAdjacencyGraph.new
    community_edges.each { |e| dg.add_edge(e[0], e[1]) }
    src = File.join("images", dir, 'dendrogram')
    dg.write_to_graphic_file("png", src)
    `rm -rf images/#{dir}/*.dot`
  end

  def self.cutoff_communities(community, min_strength)
    if community.parent && community.strength<=min_strength
      community.update(:cutoff => true)
    else
      subcommunities = Community.filter(:parent_id => community.id).all
      subcommunities.each do |sub|
        cutoff_communities(sub, min_strength)
      end
    end
  end

  def self.draw_followers_statistics(dir='.')
    data = Community.filter(:cutoff => true).all.map { |c| [c.id, followers_percent(c.id)] }
    draw_chart("Followers Statistics", "community", "followers percent", data, File.join(dir, "followers_statistics_chart"))
  end

  def self.draw_page_ranks_statistics(dir='.')
    communities = Community.filter(:cutoff => true).all
    page_rank_min = communities.map { |c| [c.id, page_ranks_min(c.id)[:page_rank]] }
    page_rank_max = communities.map { |c| [c.id, page_ranks_max(c.id)[:page_rank]] }
    users_min = communities.map { |c| [c.id, page_ranks_min(c.id)[:user]] }.map { |pair| "#{pair[0]} => #{pair[1]}" }.join(', ')
    users_max = communities.map { |c| [c.id, page_ranks_max(c.id)[:user]] }.map { |pair| "#{pair[0]} => #{pair[1]}" }.join(', ')
    avg = communities.map { |c| [c.id, page_ranks_avg(c.id)] }
    sd = communities.map { |c| [c.id, page_ranks_standard_deviation(c.id)] }
    draw_chart("Page Rank Statistics - Min", users_min, "page ranks min", page_rank_min, File.join(dir, "page_rank_statistics_min_chart"))
    draw_chart("Page Rank Statistics - Max", users_max, "page ranks max", page_rank_max, File.join(dir, "page_rank_statistics_max_chart"))
    draw_chart("Page Rank Statistics - Avarage", "community", "page ranks avg", avg, File.join(dir, "page_rank_statistics_avg_chart"))
    draw_chart("Page Rank Statistics - Standard Deviation", "community", "page ranks sd", sd, File.join(dir, "page_rank_statistics_sd_chart"))
  end

  def self.followers_percent(community_id)
    community_users = Community.first(:id => community_id).users
    edges_count = 0
    community_users.each do |u1|
      community_users.each do |u2|
        edges_count += 1 if u1.twitts.any? { |t| t.parent && t.parent.user == u2 }
      end
    end
    followers_count = 0
    community_users.each do |u|
      followers_count += u.followers.count { |f| community_users.any? { |cu| cu.id == f.user_id } }
    end
    if edges_count>0
      ratio = followers_count.to_f/edges_count
      ((ratio*100).to_i)/100.0
    else
      0.0
    end
  end

  def self.page_ranks(community_id)
    Community.first(:id => community_id).users.map { |u| [u.page_rank, u.name ? u.name : "unknown"] }.compact
  end

  def self.page_ranks_min(community_id)
    min = page_ranks(community_id).min { |a, b| a[0] <=> b[0] }
    { :page_rank => min[0].to_f.prec(2), :user => min[1] }
  end

  def self.page_ranks_max(community_id)
    max = page_ranks(community_id).max { |a, b| a[0] <=> b[0] }
    { :page_rank => max[0].to_f.prec(2), :user => max[1] }
  end

  def self.page_ranks_avg(community_id)
    page_ranks = page_ranks(community_id).map { |p| p[0] }
    if page_ranks.size>0
      (page_ranks.inject(0) { |sum, pr| sum += pr.to_f }/page_ranks.size).to_f.prec(2)
    else
      0.0
    end
  end

  def self.page_ranks_standard_deviation(community_id)
    avg = page_ranks_avg(community_id)
    Math.sqrt(page_ranks(community_id).map { |pr| (pr[0]-avg)**2 }.inject(0) { |sum, e| sum += e }).to_f.prec(2)
  end

  protected

  def save_all_communities(graph, parent)
    community = Community.create(:parent => parent, :strength => graph.strength, :density => graph.density)
    User.filter(:id => graph.community_nodes.map { |n| n.id }).each do |u|
      u.add_community(community)
      u.save
    end
    graph.subgraphs.each do |sub|
      save_all_communities(sub, community)
    end
  end

  def self.find_edges(community_node)
    community_edges = []
    children = []
    Community.filter(:parent_id => community_node.id).each do |subcommunity|
      child = CommunityNode.new(subcommunity.id, subcommunity.users.count, subcommunity.strength, subcommunity.density)
      children << child
      community_edges += [[community_node, child]] + find_edges(child)
    end
    community_edges
  end

  def self.draw_chart(title, x_label, y_label, data, file_name)
    bar = Gruff::Bar.new

    bar.title = title
    bar.x_axis_label = x_label
    bar.y_axis_label = y_label

    data.each do |id, e|
      bar.data(id, e)
    end

    dest = File.join('images', "#{file_name}.png")
    bar.write(dest)
  end
end
