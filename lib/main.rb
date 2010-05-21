require 'config/environments/development'
require 'lib/twitter_analyser'

def analyse(definition_sym, dir)
  t = TwitterAnalyser.new
  t.detect_communities!(definition_sym)
  TwitterAnalyser.draw_dendrogram(dir)
  TwitterAnalyser.draw_followers_statistics(dir)
end

t = TwitterAnalyser.new

analyse(:weak_community, 'weak_communities')
#analyse(:strong_community, 'strong_communities')
#analyse(nil, 'groups')
