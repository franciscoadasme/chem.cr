class Chem::ResidueType
  @atom_types : Array(AtomType)
  @bonds : Array(BondType)

  getter name : String
  getter kind : Residue::Kind
  getter link_bond : BondType?
  getter description : String
  getter root : AtomType?
  getter code : Char?
  getter symmetric_atom_groups : Array(Array(Tuple(String, String)))?

  def initialize(
    @description : String,
    @name : String,
    @code : Char?,
    @kind : Residue::Kind,
    atom_types : Array(AtomType),
    bonds : Array(BondType),
    @link_bond : BondType? = nil,
    @root : AtomType? = nil,
    @symmetric_atom_groups : Array(Array(Tuple(String, String)))? = nil
  )
    @atom_types = atom_types.dup
    @bonds = bonds.dup
  end

  def self.build(kind : Residue::Kind = :other) : self
    builder = ResidueType::Builder.new kind
    with builder yield builder
    builder.build
  end

  def [](atom_name : String) : AtomType
    self[atom_name]? || raise Error.new "Unknown atom type #{atom_name}"
  end

  def []?(atom_name : String) : AtomType?
    @atom_types.find &.name.==(atom_name)
  end

  def atom_count(*, include_hydrogens : Bool = true)
    size = @atom_types.size
    size -= @atom_types.count &.element.hydrogen? unless include_hydrogens
    size
  end

  def atom_names : Array(String)
    @atom_types.map &.name
  end

  def atom_types : Array(AtomType)
    @atom_types.dup
  end

  def each_atom_type(&block : AtomType ->)
    @atom_types.each &block
  end

  def bonded_atoms(atom_t : AtomType) : Array(AtomType)
    @bonds.select(&.includes?(atom_t)).map &.other(atom_t)
  end

  def bonds : Array(BondType)
    @bonds.dup
  end

  def formal_charge : Int32
    @atom_types.each.map(&.formal_charge).sum
  end

  def inspect(io : IO) : Nil
    io << "<ResidueType " << @name
    io << '(' << @code << ')' if @code
    io << ", " << @kind.to_s.downcase unless @kind.other?
    io << '>'
  end

  def monomer? : Bool
    !link_bond.nil?
  end

  def n_atoms : Int32
    @atom_types.size
  end
end
