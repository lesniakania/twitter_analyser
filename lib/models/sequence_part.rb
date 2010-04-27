class SequencePart < Sequel::Model
  many_to_one :start_edge, :class => :User, :key => :start_edge_id
  many_to_one :end_edge, :class => :User, :key => :end_edge_id
end