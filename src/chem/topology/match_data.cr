struct Chem::Topology::MatchData
  getter rtype : ResidueType
  getter resname : String

  delegate :[], :[]?, size, to: @atom_map

  def initialize(@resname : String,
                 @rtype : ResidueType,
                 @atom_map : Hash(String, Atom))
  end

  def self.new(res_t : ResidueTemplate, atom_map : Hash(String, Atom)) : self
    atom_names = res_t.atom_names
    atom_map = atom_map.to_a.sort_by! { |(k, _)| atom_names.index(k) || 99 }.to_h
    MatchData.new res_t.name, res_t.type, atom_map
  end

  def atom_names : Array(String)
    @atom_map.keys
  end

  def each_atom(& : Atom, String ->) : Nil
    @atom_map.each do |name, atom|
      yield atom, name
    end
  end

  def to_h : Hash(String, Atom)
    @atom_map.dup
  end
end
