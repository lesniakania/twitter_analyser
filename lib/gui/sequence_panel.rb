require 'wx'
include Wx

class SequencePanel < Panel
  def initialize(parent_panel, sequence)
    super(parent_panel, -1, DEFAULT_POSITION, [200,200])

    inner_panel_sizer = BoxSizer.new(VERTICAL)
    self.set_sizer inner_panel_sizer

    sequence.nick_edges.each do |nick|
      nick_label = StaticText.new(self, -1, nick)
      inner_panel_sizer.add(nick_label)
    end
  end
end
