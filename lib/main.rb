require 'config/environments/development.rb'
require 'lib/twitter_analyser.rb'

def analyse(definition_sym, dir, begin_date, end_date, number)
  t = TwitterAnalyser.new(begin_date, end_date)
  t.detect_communities!(definition_sym)
  reset_cutoff
  TwitterAnalyser.cutoff_communities(Community.root, TwitterAnalyser::MIN_STRENGTH, number)

  graphs = Graph.cutoff(t.graph, TwitterAnalyser::MIN_STRENGTH)
  graphs.each do |graph|
    TwitterAnalyser.compute_page_ranks!(graph)
  end
  TwitterAnalyser.draw_page_ranks_statistics(dir)

  TwitterAnalyser.draw_dendrogram(dir)
  TwitterAnalyser.draw_followers_statistics(dir)

  TwitterAnalyser.draw_sequences_percent_statistics(dir)
  TwitterAnalyser.draw_frequent_sequences_statistics(dir)
end

clear_logs
[[:weak_community, 'weak_communities'], [:strong_community, 'strong_communities'], [nil, 'groups']].each do |definition, dir|
  number = 1
  [
    [Time.utc(2006, 1), Time.utc(2010, 1, 17)],
    [Time.utc(2006, 1), Time.utc(2010, 1, 18)],
    [Time.utc(2006, 1), Time.utc(2010, 1, 19)],
    [Time.utc(2006, 1), Time.utc(2010, 1, 2)],
    [Time.utc(2006, 1), Time.utc(2010, 1, 3)]
  ].each do |begin_date, end_date|
    inner_dir = File.join(dir, number.to_s)
    analyse(definition, inner_dir, begin_date, end_date, number)
    number += 1
  end
  TwitterAnalyser.draw_dynamics_statistics(dir)
end

TwitterAnalyser::COMMUNITY_DEFINITIONS.each_value do |definition|
  Log.filter(:community_definition => definition).order(:number).all.each do |log|
    stat = TwitterAnalyser.dynamics_stat(log)
    puts "log.id:\t\t\t#{log.id}"
    puts "users count:\t\t#{stat.users_count}"
    puts "rejected users count:\t#{stat.rejected_users_count}"
    puts "new users count:\t#{stat.new_users_count}"
    puts "mapping:"
    p stat.next_communities_mapping
    puts
  end
end