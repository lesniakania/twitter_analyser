class Log < Sequel::Model
  one_to_many :log_users

  def next_logs
    Log.filter(:number => number+1, :community_definition => community_definition)
  end

  def prev_logs
    Log.filter(:number => number-1, :community_definition => community_definition)
  end
end
