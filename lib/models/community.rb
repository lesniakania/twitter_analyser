class Community < Sequel::Model
  many_to_one :parent, :class => :Community, :key => :parent_id
  one_to_many :users
end
