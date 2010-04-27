require 'config/environments/development'
require 'lib/twitter_analyser'

TwitterAnalyser.new.detect_communities
