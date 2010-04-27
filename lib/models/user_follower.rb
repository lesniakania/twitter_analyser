class UserFollower < Sequel::Model
  many_to_one :user, :class => :User, :key => :user_id
  many_to_one :follower, :class => :User, :key => :follower_id
end