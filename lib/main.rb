require 'config/environments/development'
require 'lib/twitter_analyser'

def analyse(definition_sym, dir)
  t = TwitterAnalyser.new
  t.detect_communities!(definition_sym)
  TwitterAnalyser.draw_dendrogram(dir)
  TwitterAnalyser.draw_followers_statistics(dir)
  TwitterAnalyser.draw_page_ranks_statistics(dir)
end

#t = TwitterAnalyser.new
#t.compute_page_ranks!
analyse(nil, 'groups')
analyse(:weak_community, 'weak_communities')
analyse(:strong_community, 'strong_communities')
