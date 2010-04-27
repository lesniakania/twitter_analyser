class Follower
  attr_accessor :user_nick, :follower_nick

  def initialize(user_nick,follower_nick)
    @user_nick = user_nick
    @follower_nick = follower_nick
  end

  def ==(follower)
    self.follower_nick == follower.follower_nick
  end
end
