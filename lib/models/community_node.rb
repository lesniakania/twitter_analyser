class CommunityNode
  attr_accessor :id, :size, :strength

  def initialize(id, size, strength)
    self.id = id
    self.size = size
    self.strength = strength
  end

  def to_s
    "#{id} (#{size}) [#{"%.2f" % strength}]"
  end

  def ==(other)
    self.id == other.id
    self.size == other.size
  end
end
