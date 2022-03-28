class Chem::ResidueType
  private REGISTRY = {} of String => ResidueType

  @atom_types : Array(AtomType)
  @bonds : Array(BondType)

  getter name : String
  getter aliases : Array(String)
  getter kind : Residue::Kind
  getter link_bond : BondType?
  getter description : String?
  getter root_atom : AtomType
  getter code : Char?
  getter symmetric_atom_groups : Array(Array(Tuple(String, String)))?

  def initialize(
    @name : String,
    @code : Char?,
    @kind : Residue::Kind,
    @description : String?,
    atom_types : Array(AtomType),
    bonds : Array(BondType),
    @root_atom : AtomType,
    @aliases : Array(String) = [] of String,
    @link_bond : BondType? = nil,
    @symmetric_atom_groups : Array(Array(Tuple(String, String)))? = nil
  )
    @atom_types = atom_types.dup
    @bonds = bonds.dup
  end

  def self.all_types : Array(ResidueType)
    REGISTRY.values
  end

  def self.build : self
    builder = ResidueType::Builder.new
    with builder yield builder
    builder.build
  end

  def self.fetch(name : String) : ResidueType
    fetch(name) { raise Error.new("Unknown residue type #{name}") }
  end

  def self.fetch(name : String, & : -> T) : ResidueType | T forall T
    REGISTRY[name]? || yield
  end

  def self.register : ResidueType
    ResidueType.build do |builder|
      with builder yield builder
      residue = builder.build
      ([residue.name] + residue.aliases).each do |name|
        raise Error.new("#{name} residue type already exists") if REGISTRY.has_key?(name)
        REGISTRY[name] = residue
      end
    end
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
