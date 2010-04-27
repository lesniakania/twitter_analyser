require 'rubygems'
require 'sequel'
require 'schema'
require 'sequence_part'
require 'sequence_freq'
require 'user'
require 'twitt'

MinSequenceFreq = 10

def init
  # 'log'
  puts "Init started..."
  
  SequencePart.delete
  SequenceFreq.delete

  vector_number = 0
  Twitt.each do |twitt|
    part_sequences = []
    while parent_twitt = twitt.parent_twitt
      part_sequences << SequencePart.new(
        :start_edge => parent_twitt.user,
        :end_edge => twitt.user,
        :vector_number => vector_number
      )
      twitt = parent_twitt
    end
    size = part_sequences.size
    part_sequences.each_with_index do |part_sequence,i|
      part_sequence.position = size-i
      part_sequence.save
    end
    vector_number += 1
  end
  
  # 'log'
  puts "init finished"
end

def prefix_span(map, pos, min_sequence_freq)
	map2 = Hash.new(0)
  sequences = []
	map.each do |key, value|
		sequences = SequencePart.filter(
      :position => pos-1,
      :start_edge_id => key[pos*2-4],
      :end_edge_id => key[pos*2-3]
    ).all
    
    sequences.each do |seq|
      tmp = pos-1
      check = 1
      while tmp > 0 and check == 1 do
        unless SequencePart.filter(
          {
            :position => tmp-1,
            :vector_number => seq.vector_number
          },
          ~{
            :start_edge_id => key[tmp*2-4],
            :end_edge_id => key[tmp*2-3]
          }
        ).empty?
          check = 0
        end
        tmp -= 1
      end
				
      if check == 1
        SequencePart.filter(
          :vector_number => seq.vector_number,
          :position => pos
        ).each do |sequence|
          if sequence != seq
            val = Array.new(key)
            map2[val.concat([sequence.start_edge.id, sequence.end_edge.id])] += 1
          end
        end
      end
    end
  end

  map2.delete_if {|key, value| value < min_sequence_freq }
  
  # 'log'
  map2.each { |k,v| puts "%s %d" % [k,v] }

  map.update(map2)

	unless sequences.empty?
		map.update(prefix_span(map2, pos + 1, min_sequence_freq))
	end
	return map2
end


def find_frequent(min_sequence_freq=MinSequenceFreq)
  init
	map = Hash.new(0)

  #pierwszy krok algorytmu; wyszukanie najkrotszych sekwencji
	SequencePart.filter(:position => 1).each do |seq|
			new_seq = [seq.start_edge.id, seq.end_edge.id]
			map[new_seq] += 1
  end
  map.delete_if {|key, value| value < min_sequence_freq }
	
	prefix_span(map, 2, min_sequence_freq)

	map.each do |sequence, frequency|
    key = sequence.join("-")
    unless existing_sequence = SequenceFreq.filter(:key => key).first
      SequenceFreq.create(:key => key, :frequency => frequency, :length => sequence.size)
    else
      existing_sequence.frequency += frequency
      existing_sequence.save
    end
  end
end

#find_frequent

require 'rubygems'
require 'gruff'
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

  src = File.join("sequences_by_frequency_line_chart.png")
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

  src = File.join("sequences_by_length_line_chart.png")
  line.write(src)
  src
end

draw_sequences_by_frequency_line_chart
draw_sequences_by_length_line_chart