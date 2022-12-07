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
    root_atom : String,
    @aliases : Array(String) = [] of String,
    @link_bond : BondTemplate? = nil,
    @symmetric_atom_groups : Array(Array(Tuple(String, String)))? = nil
  )
    @atom_table = @atoms.index_by &.name
    if atom = @atom_table[root_atom]?
      @root_atom = atom
    else
      raise KeyError.new("Atom #{root_atom.inspect} not found in #{self}")
    end
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
    raise Error.new("Cannot create template from #{residue} due to \
                     missing connectivity") if bonds.empty?

    link_bond ||= residue.template.try(&.link_bond)
    if !link_bond && (bond = guess_link_bond(residue))
      atom_templates = bond.atoms.map { |atom| atom_table[atom.name] }
      link_bond = BondTemplate.new *atom_templates, bond.order
    end

    new residue.name,
      residue.code,
      residue.type,
      description,
      atoms,
      bonds,
      atoms.first.name,
      aliases,
      link_bond,
      symmetric_atom_groups
  end

  # Returns the bond template between the given atoms. Raises `KeyError`
  # if the bond does not exist.
  def [](atom_t : AtomTemplate, other : AtomTemplate) : BondTemplate
    if bond_t = self[name, other]?
      bond_t
    else
      raise KeyError.new("Bond between #{atom_t} and #{other} not found in #{self}")
    end
  end

  # :ditto:
  def [](atom_t : String, other : String) : BondTemplate
    if bond_t = self[atom_t, other]?
      bond_t
    else
      raise KeyError.new("Bond between #{atom_t.inspect} and #{other.inspect} \
                            not found in #{self}")
    end
  end

  def [](name : String) : AtomTemplate
    self[name]? || raise KeyError.new("Atom #{name.inspect} not found in #{self}")
  end

  # Returns the bond template between the given atoms if exists, else
  # `nil`.
  def []?(atom_t : AtomTemplate, other : AtomTemplate) : BondTemplate?
    @bonds.find do |bond_t|
      atom_t.in?(bond_t) && other.in?(bond_t)
    end
  end

  # :ditto:
  def []?(name : String, other : String) : BondTemplate?
    return unless (atom_t = self[name]?) && (other_t = self[other]?)
    self[atom_t, other_t]?
  end

  def []?(name : String) : AtomTemplate?
    @atom_table[name]?
  end

  def atoms : Array::View(AtomTemplate)
    @atoms.view
  end

  def bonds : Array::View(BondTemplate)
    @bonds.view
  end

  def formal_charge : Int32
    @atoms.sum &.formal_charge
  end

  def polymer? : Bool
    !!link_bond
  end

  def to_s(io : IO) : Nil
    io << '<' << {{@type.name.split("::").last}} << ' ' << @name
    io << '(' << @code << ')' if @code
    io << ' ' << @type.to_s.downcase unless @type.other?
    io << '>'
  end
end

# Checks that the residue is connected to two other residues by
# equivalent bonds and returns one of them, else `nil`.
private def guess_link_bond(residue : Chem::Residue) : Chem::Bond?
  bonded_residues = residue.bonded_residues
  return if bonded_residues.empty?

  if bonded_residues.size == 1 # may be at the beginning/end of a polymer
    residue = bonded_residues.first
    bonded_residues = residue.bonded_residues
    # residue is only connected to the original one, need at least two
    # bonded residues (two bonds) to guess link bond
    return unless bonded_residues.size > 1
  end

  pred, succ = bonded_residues.sort! &.number
  pred, succ = succ, pred if pred.number > residue.number # periodic chain?

  pred_bond = succ_bond = nil
  residue.bonds.each do |bond|
    pred_bond ||= bond if bond.atoms.any?(&.in?(pred))
    succ_bond ||= bond if bond.atoms.any?(&.in?(succ))
  end

  if pred_bond && succ_bond
    atom_names = pred_bond.atoms.map(&.name)
    succ_bond if (atom_names == succ_bond.atoms.map(&.name) ||
                 atom_names.reverse == succ_bond.atoms.map(&.name))
  end
end
