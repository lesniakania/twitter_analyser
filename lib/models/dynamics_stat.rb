class DynamicsStat
  attr_accessor :community_id, :users_count, :next_communities_mapping, :rejected_users_count, :new_users_count

  def initialize(community_id, users_count, next_communities_mapping, rejected_users_count, new_users_count)
    self.community_id = community_id
    self.users_count = users_count
    self.next_communities_mapping = next_communities_mapping
    self.rejected_users_count = rejected_users_count
    self.new_users_count = new_users_count
  end

  def to_s
    "#{community_id} (#{users_count}) [new #{new_users_count}]"
  end
end
