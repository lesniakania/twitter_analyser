class DynamicsStat
  attr_accessor :users_count, :next_communities_mapping, :rejected_users_count, :new_users_count

  def initialize(users_count, next_communities_mapping, rejected_users_count, new_users_count)
    self.users_count = users_count
    self.next_communities_mapping = next_communities_mapping
    self.rejected_users_count = rejected_users_count
    self.new_users_count = new_users_count
  end
end
