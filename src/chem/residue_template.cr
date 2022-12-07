require "yaml"

class Chem::ResidueTemplate
  @atoms : Array(AtomTemplate)
  @atom_table : Hash(String, AtomTemplate)
  @bonds : Array(BondTemplate)

  getter name : String
  getter aliases : Array(String)
  getter type : ResidueType
  getter link_bond : BondTemplate?
  getter description : String?
  # TODO: change to String, and check that exists
  getter root_atom : AtomTemplate
  getter code : Char?
  getter symmetric_atom_groups : Array(Array(Tuple(String, String)))?

  def initialize(
    @name : String,
    @code : Char?,
    @type : ResidueType,
    @description : String?,
    @atoms : Array(AtomTemplate),
    @bonds : Array(BondTemplate),
    @root_atom : AtomTemplate,
    @aliases : Array(String) = [] of String,
    @link_bond : BondTemplate? = nil,
    @symmetric_atom_groups : Array(Array(Tuple(String, String)))? = nil
  )
    @atom_table = @atoms.index_by &.name
  end

  def self.build : self
    builder = ResidueTemplate::Builder.new
    with builder yield builder
    builder.build
  end

  # Creates a new residue template from an existing residue.
  #
  # Every atom and bond is converted to a template, which are then
  # passed down to the constructor along with the optional arguments.
  # Information such as name, code, etc. is obtained from the residue.
  def self.from_residue(
    residue : Residue,
    description : String? = nil,
    aliases : Array(String) = [] of String,
    link_bond : BondTemplate? = nil,
    symmetric_atom_groups : Array(Array(Tuple(String, String)))? = nil
  ) : self
    atoms = residue.atoms.map do |atom|
      AtomTemplate.new(atom.name, atom.element, atom.valence, atom.formal_charge)
    end
    atom_table = atoms.index_by &.name
    bonds = residue.bonds.map do |bond|
      BondTemplate.new *bond.atoms.map { |atom| atom_table[atom.name] }, bond.order
    end
    root = atoms.first
    new residue.name,
      residue.code,
      residue.type,
      description,
      atoms,
      bonds,
      root,
      aliases,
      link_bond,
      symmetric_atom_groups
  end

  def [](name : String) : AtomTemplate
    self[name]? || raise Error.new("Unknown atom template #{name.inspect} in #{@name}")
  end

  def []?(name : String) : AtomTemplate?
    @atom_table[name]?
  end

  def atom_count(*, include_hydrogens : Bool = true)
    size = @atoms.size
    size -= @atoms.count &.element.hydrogen? unless include_hydrogens
    size
  end

  def atom_names : Array(String)
    @atoms.map &.name
  end

  def atoms : Array(AtomTemplate)
    @atoms.dup
  end

  def each_atom_t(&block : AtomTemplate ->)
    @atoms.each &block
  end

  def bonded_atoms(atom_t : AtomTemplate) : Array(AtomTemplate)
    @bonds.select(&.includes?(atom_t)).map &.other(atom_t)
  end

  def bonds : Array(BondTemplate)
    @bonds.dup
  end

  def formal_charge : Int32
    @atoms.each.map(&.formal_charge).sum
  end

  def inspect(io : IO) : Nil
    io << "<ResidueTemplate " << @name
    io << '(' << @code << ')' if @code
    io << ", " << @type.to_s.downcase unless @type.other?
    io << '>'
  end

  def monomer? : Bool
    !link_bond.nil?
  end

  def n_atoms : Int32
    @atoms.size
  end
end
