require 'config/environments/development'
require 'lib/twitter_analyser'

t = TwitterAnalyser.new
t.detect_communities
TwitterAnalyser.draw_dendrogram

