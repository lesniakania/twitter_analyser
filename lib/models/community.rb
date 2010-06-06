class Community < Sequel::Model
  many_to_one :parent, :class => :Community, :key => :parent_id
  many_to_many :users
  
  def self.root
    Community.first(:parent_id => nil)
  end
end
