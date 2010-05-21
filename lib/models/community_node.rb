class CommunityNode
  attr_accessor :id, :size, :strength, :density

  def initialize(id, size, strength, density)
    self.id = id
    self.size = size
    self.strength = strength
    self.density = density
  end

  def to_s
    "#{id} (#{size}) [#{"%.2f%" % strength} / #{density}]"
  end

  def ==(other)
    self.id == other.id
    self.size == other.size
  end
end
