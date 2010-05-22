class SequenceFreq < Sequel::Model
  unrestrict_primary_key

  def nodes
    self.key.split("-").map { |id| id.to_i }
  end

  def chart_edges
    chart_edges = []
    nodes.map { |n| n.to_s }.each_with_index do |o,i|
      chart_edges << o if i == 0 or i % 2 == 1
    end
    chart_edges
  end

  def graph_edges
    edges = nick_edges
    edges[0..edges.size-2].zip(edges[1..edges.size-1])
  end

  def nick_edges
    chart_edges.map { |e| User.filter(:id => e.to_i).first.nick }
  end

  def to_s
    chart_edges.join(">")
  end
end
