require 'lib/models/sequence_part'
require 'lib/models/sequence_freq'
require 'lib/models/user'
require 'lib/models/twitt'

MinSequenceFreq = 10

class PrefixSpan
  def initialize(twitts)
    # 'log'
    puts "Init started..."

    SequencePart.delete
    SequenceFreq.delete

    vector_number = 0
    twitts.each do |twitt|
      part_sequences = []
      while parent_twitt = twitt.parent
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
end
