class User < Sequel::Model
  one_to_many :twitts, :class => :Twitt, :key => :user_id
  one_to_many :followers, :class => :UserFollower, :key => :user_id
  many_to_one :community
end
