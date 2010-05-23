require 'config/environments/development'
require 'lib/twitter_analyser'

def analyse(definition_sym, dir)
  t = TwitterAnalyser.new
  t.detect_communities!(definition_sym)
  TwitterAnalyser.cutoff_communities(Community.root, 70)

  graphs = Graph.cutoff(t.graph, 70)
  graphs.each do |graph|
    TwitterAnalyser.compute_page_ranks!(graph)
  end
  TwitterAnalyser.draw_page_ranks_statistics(dir)

  TwitterAnalyser.draw_dendrogram(dir)
  TwitterAnalyser.draw_followers_statistics(dir)

  TwitterAnalyser.draw_sequences_percent_statistics(dir)
  TwitterAnalyser.draw_frequent_sequences_statistics(dir)
end

analyse(:weak_community, 'weak_communities')
analyse(:strong_community, 'strong_communities')
analyse(nil, 'groups')

