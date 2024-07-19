class Chem::Templates::Residue
  @atoms : Array(Atom)
  @atom_table : Hash(String, Atom)
  @bonds : Array(Bond)

  getter names : Array(String)
  getter type : ResidueType
  getter link_bond : Bond?
  getter description : String?
  getter root : Atom
  getter code : Char?
  getter symmetric_atom_groups : Array(Array(Tuple(String, String)))?

  def initialize(
    @names : Array(String),
    @code : Char?,
    @type : ResidueType,
    @description : String?,
    @atoms : Array(Atom),
    @bonds : Array(Bond),
    root root_name : String,
    @link_bond : Bond? = nil,
    @symmetric_atom_groups : Array(Array(Tuple(String, String)))? = nil
  )
    raise ArgumentError.new("Empty residue template names") if names.empty?

    @atom_table = @atoms.index_by &.name
    @root = @atom_table.fetch(root_name) { unknown_atom(root_name) }

    if @atom_table.size < atoms.size # atom_table includes unique names only
      name, _ = @atoms.map(&.name).tally.max_by(&.[1])
      raise Error.new("Duplicate atom name #{name.inspect} found in #{self}")
    end

    @link_bond.try do |link_bond|
      if link_bond.atoms.any? { |atom_t| atom_t != self[atom_t.name] }
        raise Error.new("Incompatible link bond #{link_bond} with #{self}")
      end
    end

    @symmetric_atom_groups.try do |groups|
      groups.each do |pairs|
        pairs.each do |pair|
          pair.each do |name|
            unknown_atom(name) unless @atom_table[name]?
          end
        end
      end
    end
  end

  def self.build : self
    builder = Builder.new
    with builder yield builder
    builder.build
  end

  # Creates a new residue template from an existing residue.
  #
  # Every atom and bond is converted to a template, which are then
  # passed down to the constructor along with the optional arguments.
  # Information such as name, code, etc. is obtained from the residue.
  #
  # If *link_bond* is `nil`, it will be obtained from the associated
  # residue template if exists. Otherwise, it will be guessed from the
  # connectivity. If the residue is connected to two other residues by
  # equivalent bonds, one of them will be chosen. The sense of the link
  # bond will be inferred from the residue numbering.
  #
  # Raises `Error` if there is missing connectivity (no bonds).
  def self.build(
    residue : ::Chem::Residue,
    description : String? = nil,
    link_bond : Bond? = nil,
    symmetric_atom_groups : Array(Array(Tuple(String, String)))? = nil
  ) : self
    atoms = residue.atoms.map do |atom|
      Atom.new(atom.name, atom.element, atom.bonded_atoms.map(&.element),
        atom.formal_charge, atom.valence)
    end
    atom_table = atoms.index_by &.name
    if atom_table.size < atoms.size
      name, _ = atoms.map(&.name).tally.max_by(&.[1])
      raise Error.new("Duplicate atom name #{name.inspect} found in #{residue}")
    end

    bonds = residue.atoms.bonds.map do |bond|
      Bond.new *bond.atoms.map { |atom| atom_table[atom.name] }, bond.order
    end
    raise Error.new("Cannot create template from #{residue} due to \
                     missing connectivity") if bonds.empty?

    link_bond ||= residue.template.try(&.link_bond)
    if !link_bond && (bond = guess_link_bond(residue))
      atom_templates = bond.atoms.map { |atom| atom_table[atom.name] }
      link_bond = Bond.new *atom_templates, bond.order
    end

    new [residue.name],
      residue.code,
      residue.type,
      description,
      atoms,
      bonds,
      Builder.guess_root(atoms, bonds, link_bond),
      link_bond,
      symmetric_atom_groups
  end

  # Returns the bond template between the given atoms. Raises `KeyError`
  # if the bond does not exist.
  def [](atom_t : Atom, other : Atom) : Bond
    self[name, other]? || unknown_bond(atom_t, other)
  end

  # :ditto:
  def [](name : String, other : String) : Bond
    self[name, other]? || unknown_bond(name, other)
  end

  def [](name : String) : Atom
    self[name]? || unknown_atom(name)
  end

  # Returns the bond template between the given atoms if exists, else
  # `nil`.
  def []?(atom_t : Atom, other : Atom) : Bond?
    @bonds.find do |bond_t|
      atom_t.in?(bond_t) && other.in?(bond_t)
    end
  end

  # :ditto:
  def []?(name : String, other : String) : Bond?
    return unless (atom_t = self[name]?) && (other_t = self[other]?)
    self[atom_t, other_t]?
  end

  def []?(name : String) : Atom?
    @atom_table[name]?
  end

  def atoms : Array::View(Atom)
    @atoms.view
  end

  def bonds : Array::View(Bond)
    @bonds.view
  end

  def formal_charge : Int32
    @atoms.sum &.formal_charge
  end

  # Returns the designated residue name.
  def name : String
    @names.first
  end

  def polymer? : Bool
    !!link_bond
  end

  def to_s(io : IO) : Nil
    io << '<' << {{@type.name.split("::")[1..].join("::")}} << ' ' << name
    io << '(' << @code << ')' if @code
    io << ' ' << @type.to_s.downcase unless @type.other?
    io << '>'
  end

  private def unknown_atom(name : String) : Nil
    raise KeyError.new("Atom #{name.inspect} not found in #{self}")
  end

  private def unknown_bond(name : String, other : String) : Nil
    raise KeyError.new("Bond between #{name.inspect} and #{other.inspect} \
                        not found in #{self}")
  end

  private def unknown_bond(atom_t : Atom, other : Atom) : Nil
    raise KeyError.new("Bond between #{atom_t} and #{other} not found in #{self}")
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
  residue.atoms.bonds.each do |bond|
    pred_bond ||= bond if bond.atoms.any?(&.in?(pred))
    succ_bond ||= bond if bond.atoms.any?(&.in?(succ))
  end

  if pred_bond && succ_bond
    atom_names = pred_bond.atoms.map(&.name)
    succ_bond if (atom_names == succ_bond.atoms.map(&.name) ||
                 atom_names.reverse == succ_bond.atoms.map(&.name))
  end
end
