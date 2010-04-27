require 'rubygems'
require 'spider'
require 'sequel'
require 'schema'
require 'gruff'
require 'rgl/adjacency'
require 'rgl/dot'
require 'sequence_freq'
require 'prefix_span'
require 'legend_frame'
require 'wx'
include Wx

class Main < Frame
  ImagesDir = "../images"
  Wx::CHANGE_MODE = 1
  Wx::REPAINT_GRAPH = 2
  Wx::DRAW_FREQUENCY_BY_SEQUENCES_BAR_CHART = 3
  Wx::SHOW_LEGEND = 4
  Wx::DRAW_SEQUENCES_BY_FREQUENCY_LINE_CHART = 5
  Wx::DRAW_SEQUENCES_BY_LENGTH_LINE_CHART = 6
  Wx::RERUN_SPIDER = 7
  Wx::RERUN_PREFIX_SPAN = 8

  def initialize
    super(nil, -1, 'The most frequent Twitter sequences',
      :size => [400, 600]
    )
    
    @limit = 0        # no limit, retrive all sequences in database
    @min_length = 5
    @max_length = 0
    @begin_date = nil
    @end_date = nil
    @min_sequence_freq = MinSequenceFreq
    
    @sequences = retrieve_sequences
    @all_size = SequenceFreq.all.size

    menu = Wx::MenuBar.new
    file = Wx::Menu.new
    data = Wx::Menu.new
    help = Wx::Menu.new
    file.append(Wx::CHANGE_MODE, "Change mode", "Change mode")
    file.append(Wx::REPAINT_GRAPH, "Repaint graph", "Repaint graph")

    charts = Wx::Menu.new
    charts.append(Wx::DRAW_FREQUENCY_BY_SEQUENCES_BAR_CHART, "frequencies by sequency", "bar_chart")
    charts.append(Wx::SHOW_LEGEND, "show legend", "show_legend")
    charts.append(Wx::DRAW_SEQUENCES_BY_FREQUENCY_LINE_CHART, "number of sequences by frequency", "line_chart1")
    charts.append(Wx::DRAW_SEQUENCES_BY_LENGTH_LINE_CHART, "number of sequences by length", "line_chart2")
    file.append_menu(Wx::ID_ANY,"Chart", charts)

    file.append_separator

    file.append(Wx::ID_EXIT, "Quit", "Quit")
    menu.append(file, "&File")

    data.append(Wx::RERUN_SPIDER, "rerun spider", "rerun_spider")
    data.append(Wx::RERUN_PREFIX_SPAN, "rerun prefix span", "rerun_prefix_span")
    menu.append(data, "&Data")

    help.append(Wx::ID_ABOUT, "About")
    menu.append(help, "&Help")


    self.menu_bar = menu
    self.clear

    on_repaint_graph

    self.centre
    self.show

    # events
    
    evt_menu(Wx::CHANGE_MODE, :on_change_mode)
    evt_menu(Wx::REPAINT_GRAPH, :on_repaint_graph)
    evt_menu(Wx::DRAW_FREQUENCY_BY_SEQUENCES_BAR_CHART, :on_draw_frequency_by_sequences_bar_chart)
    evt_menu(Wx::SHOW_LEGEND, :on_show_legend)
    evt_menu(Wx::DRAW_SEQUENCES_BY_FREQUENCY_LINE_CHART, :on_draw_sequences_by_frequency_line_chart)
    evt_menu(Wx::DRAW_SEQUENCES_BY_LENGTH_LINE_CHART, :on_draw_sequences_by_length_line_chart)
    evt_menu(Wx::ID_EXIT, :on_quit)

    evt_menu(Wx::RERUN_SPIDER, :on_rerun_spider)
    evt_menu(Wx::RERUN_PREFIX_SPAN, :on_rerun_prefix_span)

    evt_menu(Wx::ID_ABOUT, :on_about)
  end

  def retrieve_sequences
    if @limit > 0
      retrieve_by_length(@min_length, @max_length).limit(@limit).all
    else
      retrieve_by_length(@min_length, @max_length).all
    end
    
  end

  def retrieve_by_length(min_length, max_length)
    if max_length > 0
      SequenceFreq.filter(:length > min_length, :length < max_length).
        reverse_order(:frequency)
    else
      SequenceFreq.filter(:length > min_length).
        reverse_order(:frequency)
    end
  end

  def clear
    self.destroy_children
    
    @scroll_panel = ScrolledWindow.new(self, -1, DEFAULT_POSITION, DEFAULT_SIZE)
    @scroll_panel.enable_scrolling(true,true)
    @scroll_panel.set_scrollbars(20, 20, 50, 0, 0, 0)
    
    @inner_panel = Panel.new(@scroll_panel)

    @sizer = BoxSizer.new(VERTICAL)
    @inner_panel.set_sizer @sizer

    scroll_panel_sizer = BoxSizer.new(VERTICAL)
    @scroll_panel.set_sizer(scroll_panel_sizer)
    scroll_panel_sizer.add(@inner_panel, 0, Wx::ALIGN_CENTER, 2)

    self.client_size = [400,400]
  end

  def on_rerun_prefix_span
    modal = MessageDialog.new(@inner_panel, "Are you sure? This will last a while and recreate data in SequenceParts and SequenceFreqs.",
      "Are you sure?", Wx::OK | Wx::CANCEL, DEFAULT_POSITION)

    case modal.show_modal()
    when Wx::ID_OK
      rerun_prefix_span
    end
  end

  def on_rerun_spider
    modal = MessageDialog.new(@inner_panel, "Are you sure? This will last long time and destroy all your current data.",
      "Are you sure?", Wx::OK | Wx::CANCEL, DEFAULT_POSITION)

    case modal.show_modal()
    when Wx::ID_OK
      rerun_spider
    end
  end

  def rerun_prefix_span
    modal = MessageDialog.new(@inner_panel, "Cuputing...",
      "Please wait", Wx::OK, DEFAULT_POSITION)
    modal.show_modal()
    find_frequent(@min_sequence_freq)
  end

  def rerun_spider
    modal = MessageDialog.new(@inner_panel, "Cuputing...",
      "Please wait", Wx::OK, DEFAULT_POSITION)
    modal.show_modal()
    clear_tables
    Spider.new("Dziamka",-1).scan_twitter()
  end

  def on_change_mode
    self.clear
    
    # minimum sequence frequency
    @sizer.add_spacer(10)
    min_sequence_freq_label = StaticText.new(@inner_panel, -1, 'sequence minimum frequency (prefix span)')
    min_sequence_freq_input = Wx::TextCtrl.new(@inner_panel, -1, @min_sequence_freq.to_s,
      Wx::DEFAULT_POSITION, [100, 30])
    @sizer.add(min_sequence_freq_label, 0, Wx::CENTER | Wx::ALL, 2)
    @sizer.add(min_sequence_freq_input, 0, Wx::CENTER | Wx::ALL, 2)

    # sequences display limit
    @sizer.add_spacer(20)
    limit_checkbox = CheckBox.new(@inner_panel, -1, "restrict sequences display limit",
      Wx::DEFAULT_POSITION, Wx::DEFAULT_SIZE)
    sequences_limit_label = StaticText.new(@inner_panel, -1, 'sequences count limit')
    sequences_limit_input = Wx::TextCtrl.new(@inner_panel, -1, @limit.to_s,
      Wx::DEFAULT_POSITION, [100, 30])

    @sizer.add(limit_checkbox, 0, Wx::CENTER | Wx::ALL, 2)
    @sizer.add(sequences_limit_label, 0, Wx::CENTER | Wx::ALL, 2)
    @sizer.add(sequences_limit_input, 0, Wx::CENTER | Wx::ALL, 2)

    limit_checkbox.set_value(false)
    sequences_limit_input.disable

    evt_checkbox(limit_checkbox) do
      if limit_checkbox.is_checked
        sequences_limit_input.enable
      else
        sequences_limit_input.disable
      end
    end

    # min sequence length
    min_length_checkbox = CheckBox.new(@inner_panel, -1, "restrict mininal sequence length",
      Wx::DEFAULT_POSITION, Wx::DEFAULT_SIZE)
    
    @sizer.add_spacer(20)
    @sizer.add(min_length_checkbox, 0, Wx::CENTER | Wx::ALL, 2)
   
    sequences_min_length_label = StaticText.new(@inner_panel, -1, 'sequence minimal length')
    sequences_min_length_input = Wx::TextCtrl.new(@inner_panel, -1, @min_length.to_s,
      Wx::DEFAULT_POSITION, [100, 30])


    min_length_checkbox.set_value(false)
    sequences_min_length_input.disable
    
    evt_checkbox(min_length_checkbox) do
      if min_length_checkbox.is_checked
        sequences_min_length_input.enable
      else
        sequences_min_length_input.disable
      end
    end

    @sizer.add(sequences_min_length_label, 0, Wx::CENTER | Wx::ALL, 2)
    @sizer.add(sequences_min_length_input, 0, Wx::CENTER | Wx::ALL, 2)

    # max sequence length

    @sizer.add_spacer(20)
    max_length_checkbox = CheckBox.new(@inner_panel, -1, "restrict maximal sequence length",
      Wx::DEFAULT_POSITION, Wx::DEFAULT_SIZE)
    @sizer.add(max_length_checkbox, 0, Wx::CENTER | Wx::ALL, 2)
    
    sequences_max_length_label = StaticText.new(@inner_panel, -1, 'sequence maximal length')
    sequences_max_length_input = Wx::TextCtrl.new(@inner_panel, -1, @max_length.to_s,
      Wx::DEFAULT_POSITION, [100, 30])


    max_length_checkbox.set_value(false)
    sequences_max_length_input.disable

    evt_checkbox(max_length_checkbox) do
      if max_length_checkbox.is_checked
        sequences_max_length_input.enable
      else
        sequences_max_length_input.disable
      end
    end

    @sizer.add(sequences_max_length_label, 0, Wx::CENTER | Wx::ALL, 2)
    @sizer.add(sequences_max_length_input, 0, Wx::CENTER | Wx::ALL, 2)

    # date picker

    date_checkbox = CheckBox.new(@inner_panel, -1, "restrict time period",
      Wx::DEFAULT_POSITION, Wx::DEFAULT_SIZE)

    @sizer.add_spacer(20)
    @sizer.add(date_checkbox, 0, Wx::CENTER | Wx::ALL, 2)

    begin_date = DatePickerCtrl.new(@inner_panel, -1, Time.now, DEFAULT_POSITION,
      DEFAULT_SIZE, DP_DEFAULT | DP_SHOWCENTURY, DEFAULT_VALIDATOR)
    end_date = DatePickerCtrl.new(@inner_panel, -1, Time.now, DEFAULT_POSITION,
      DEFAULT_SIZE, DP_DEFAULT | DP_SHOWCENTURY, DEFAULT_VALIDATOR)

    date_checkbox.set_value(false)
    begin_date.disable
    end_date.disable

    evt_checkbox(date_checkbox) do
      if date_checkbox.is_checked
        begin_date.enable
        end_date.enable
      else
        begin_date.disable
        end_date.disable
      end
    end

    begin_date_label = StaticText.new(@inner_panel, -1, 'set begin date')
    @sizer.add(begin_date_label, 0, Wx::CENTER | Wx::ALL, 2)
    @sizer.add(begin_date, 0, Wx::CENTER | Wx::ALL, 2)
    end_date_label = StaticText.new(@inner_panel, -1, 'set end date')
    @sizer.add(end_date_label, 0, Wx::CENTER | Wx::ALL, 2)
    @sizer.add(end_date, 0, Wx::CENTER | Wx::ALL, 2)
    
    # button

    @sizer.add_spacer(20)
    button = Wx::Button.new(@inner_panel, -1, 'change')
    @sizer.add(button, 0, Wx::ALIGN_CENTER, 2)

    evt_button(button) do
      if (min_length_checkbox.is_checked and sequences_min_length_input.empty?) or
          (max_length_checkbox.is_checked and sequences_max_length_input.empty?) or
          (limit_checkbox.is_checked and sequences_limit_input.empty?) or
          (min_sequence_freq_input.empty?)
        modal = MessageDialog.new(@inner_panel, "Sequence min frequency, limit, min and max size must be a number equal or greater then zero.",
          "validation error", Wx::OK, DEFAULT_POSITION)
        modal.show_modal()
      else
        @min_sequence_freq = min_sequence_freq_input.get_value.to_i
        @limit = sequences_limit_input.get_value.to_i if limit_checkbox.is_checked
        @min_length = sequences_min_length_input.get_value.to_i if min_length_checkbox.is_checked
        @max_length = sequences_max_length_input.get_value.to_i if max_length_checkbox.is_checked
        if date_checkbox.is_checked
          @begin_date = begin_date.get_value
          @end_date = end_date.get_value
        end

        @sequences = retrieve_sequences
        on_repaint_graph
      end
    end

    self.send_size_event
  end

  def on_repaint_graph
    self.clear

    unless @sequences.empty?
      src = draw_graph
      draw_image(src)
    else
      label = StaticText.new(@inner_panel, -1, 'No sequences found.')
      @sizer.add_spacer(30)
      @sizer.add(label, 0, Wx::CENTER | Wx::ALL, 2)
    end
  end

  def on_draw_frequency_by_sequences_bar_chart
    self.clear
    
    src = draw_frequency_by_sequences_bar_chart
    draw_image(src)
  end

  def on_draw_sequences_by_frequency_line_chart
    self.clear

    src = draw_sequences_by_frequency_line_chart
    draw_image(src)
  end

  def on_draw_sequences_by_length_line_chart
    self.clear

    src = draw_sequences_by_length_line_chart
    draw_image(src)
  end

  def on_show_legend
    @legend_frame = LegendFrame.new(@inner_panel,@sequences)
    @legend_frame.show
  end

  def on_quit
    close
  end

  def on_about
    Wx::about_box(
      :name => "OSZDB",
      :version => "2009",
      :description => "The most frequent Twitter sequences\nAnna Leśniak & Joanna Duda",
      :developers => ['Anna Leśniak', 'Joanna Duda']
    )
  end

  def draw_image(src)
    @bmp = Wx::Bitmap.new(src, Wx::BITMAP_TYPE_PNG)
    @sizer.add(Wx::StaticBitmap.new(@inner_panel, -1, @bmp))

    width = @bmp.get_width
    height = @bmp.get_height
    width = width < 900 ? width+20 : 900
    height = height < 700 ? height+20 : 700

    self.client_size = [width, height]
    self.centre
    self.send_size_event
  end

  def draw_graph
    dg = RGL::DirectedAdjacencyGraph.new

    @sequences.each do |sequence|
      sequence.graph_edges.each do |edge|
        draw_edge(dg, *edge)
      end
    end

    src = File.join(ImagesDir, 'graph')
    dg.write_to_graphic_file('png', src)
    src + '.png'
  end

  def draw_edge(dg, v1, v2)
    dg.add_edge(v1,v2)
  end

  def draw_frequency_by_sequences_bar_chart
    bar = Gruff::Bar.new
    
    bar.title = 'The most frequent Twitter sequences'
    bar.legend_box_size = 10
    bar.legend_font_size = 13
    bar.hide_legend = true

    # label
    all_size_label = "All in database: #{@all_size}."
    limit_label = "Limit set to: #{@limit}."
    displayed_label = "Displayed: #{@sequences.size}."
    min = @min_length ? @min_length.to_s : "n/a"
    max = @max_length ? @max_length.to_s : "n/a"
    min_length_label = "Sequence lenght: min #{min}, max: #{max}."
    label = "#{all_size_label}                                               #{limit_label}\n#{displayed_label}                              #{min_length_label}"
    bar.x_axis_label = label
    bar.y_axis_label = "frequency"

    @sequences.each do |sequence|
      bar.data(sequence.to_s, sequence.frequency)
    end

    bar.labels = { 0 => "sequences"}

    src = File.join(ImagesDir, "bar_chart.png")
    bar.write(src)    
    src
  end

  def draw_sequences_by_frequency_line_chart
    line = Gruff::Line.new
    line.title = 'The most frequent Twitter sequences'

    subtitle = "number of sequences by frequency"
    data = SequenceFreq.group_and_count(:frequency).order(:frequency)
    y_axis = data.map { |o| o.values[:count]}
    line.data(subtitle, y_axis)

    x_labels = {}
    data.each_with_index do |sequence,i|
      x_labels[i] = sequence.values[:frequency].to_s
    end
    line.marker_font_size = 11
    line.labels = x_labels
    
    line.x_axis_label = "frequency"
    line.y_axis_label = "count"

    src = File.join(ImagesDir, "sequences_by_frequency_line_chart.png")
    line.write(src)
    src
  end

  def draw_sequences_by_length_line_chart
    line = Gruff::Line.new
    line.title = 'The most frequent Twitter sequences'

    subtitle = "number of sequences by length"
    data = SequenceFreq.group_and_count(:length).order(:length)
    y_axis = data.map { |o| o.values[:count]}
    line.data(subtitle, y_axis)

    x_labels = {}
    data.each_with_index do |sequence,i|
      x_labels[i] = sequence.values[:length].to_s
    end
    line.marker_font_size = 11
    line.labels = x_labels

    line.x_axis_label = "length"
    line.y_axis_label = "count"

    src = File.join(ImagesDir, "sequences_by_length_line_chart.png")
    line.write(src)
    src
  end
end

class TwitterApp < App
  def on_init
    Main.new
  end
end

TwitterApp.new.main_loop()
