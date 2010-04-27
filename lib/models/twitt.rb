class Twitt < Sequel::Model
  many_to_one :user, :class => :User, :key => :user_id
  many_to_one :parent, :class => :Twitt, :key => :parent_id

  unrestrict_primary_key
end
