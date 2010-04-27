require 'wx'
include Wx
require 'sequence_panel'

class LegendFrame < Frame
  def initialize(parent_frame, sequences)
    super(parent_frame, -1, "Legend", DEFAULT_POSITION, [400,500])
    @scroll_panel = ScrolledWindow.new(self, -1, DEFAULT_POSITION, DEFAULT_SIZE)
    @scroll_panel.enable_scrolling(true,true)
    @scroll_panel.set_scrollbars(20, 20, 50, 25, 100, 0)

    inner_panel = Panel.new(@scroll_panel)

    inner_panel_sizer = BoxSizer.new(VERTICAL)
    inner_panel.set_sizer inner_panel_sizer

    sequences.each_with_index do |sequence, i|
      label = StaticText.new(inner_panel, -1, (i+1).to_s + ". frequency: " + sequence.frequency.to_s)
      panel = SequencePanel.new(inner_panel, sequence)
      inner_panel_sizer.add(label, 0, Wx::ALL, 10)
      inner_panel_sizer.add(panel, 0, Wx::ALL, 20)
    end

    scroll_panel_sizer = BoxSizer.new(VERTICAL)
    @scroll_panel.set_sizer(scroll_panel_sizer)
    scroll_panel_sizer.add(inner_panel)
  end
end
