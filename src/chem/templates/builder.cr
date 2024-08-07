# TODO: add docs (include checks)
class Chem::Templates::Builder
  @code : Char?
  @description : String?
  @type : ResidueType = :other
  @link_bond : Tuple(String, String, BondOrder)?
  @names = [] of String
  @root_name : String?
  @symmetric_atom_groups = [] of Array(Tuple(String, String))
  @spec_parser : SpecParser?

  def initialize(@spec_aliases : Hash(String, String)? = nil)
  end

  def build : Residue
    raise "Missing residue name" if @names.empty?
    raise "Empty structure" unless parser = @spec_parser
    if @type.protein? && {"C", "N", "CA"}.none? { |name| parser.atom_map[name]? }
      raise "Missing backbone atoms for #{@names.first}"
    end

    atom_t_map = {} of String => Atom
    bond_ts = [] of Bond
    name_gen = HydrogenNameGenerator.new
    bonded_h_table = {} of String => Array(Atom)
    parser.atoms.sort_by(&.element.atomic_number.-).each do |atom|
      bonds = parser.bonds.select { |bond| atom.name.in?(bond.lhs, bond.rhs) }
      implicit_bonds = parser.implicit_bonds.select { |bond| bond.lhs == atom.name }

      # Calculate effective valence
      effective_valence = atom.explicit_hydrogens || 0
      effective_valence += atom.formal_charge *
                           (atom.element.valence_electrons >= 4 ? -1 : 1)
      effective_valence += bonds.sum &.order.to_i
      effective_valence += implicit_bonds.sum(&.order.to_i)
      if bond = @link_bond
        effective_valence += bond[2].to_i if atom.name.in?(bond)
      end

      # Check that effective valence is correct
      target_valence = atom.element.target_valence(effective_valence)
      if effective_valence > target_valence ||
         (atom.explicit_hydrogens && effective_valence != target_valence)
        raise "Expected valence of #{atom.name} is #{target_valence}, \
               got #{effective_valence}"
      end
      h_count = atom.explicit_hydrogens || (target_valence - effective_valence)

      # Gather the bonded elements that defines the atom template
      bonded_elements = bonds.map do |bond|
        parser.atom_map[atom.name == bond.lhs ? bond.rhs : bond.lhs].element
      end
      bonded_elements.concat implicit_bonds.map(&.rhs)
      @link_bond.try do |lhs, rhs, order|
        case atom.name
        when lhs then bonded_elements << parser.atom_map[rhs].element
        when rhs then bonded_elements << parser.atom_map[lhs].element
        end
      end
      h_count.times { bonded_elements << PeriodicTable::H }

      # Create and register atom template
      atom_t = Atom.new(atom.name, atom.element, bonded_elements,
        atom.formal_charge, target_valence)
      atom_t_map[atom_t.name] = atom_t

      # Add hydrogens (either explicit or implicit)
      h_count.times do |i|
        name = name_gen.next_for(atom_t, (i if h_count > 1))
        h_atom = Atom.new(name, PeriodicTable::H, [atom_t.element])
        (bonded_h_table[atom_t.name] ||= [] of Atom) << h_atom
        bond_ts << Bond.new(atom_t, h_atom)
      end
    end

    # Adds the atoms in the original order
    atoms = [] of Atom
    parser.atoms.each do |atom_r|
      atoms << atom_t_map[atom_r.name]
      if h_atoms = bonded_h_table[atom_r.name]?
        atoms.concat h_atoms
      end
    end

    parser.bonds.each do |bond|
      bond_ts << Bond.new(
        atom_t_map[bond.lhs],
        atom_t_map[bond.rhs],
        bond.order)
    end

    link_bond = @link_bond.try do |lhs, rhs, order|
      Bond.new(atom_t_map[lhs], atom_t_map[rhs], order)
    end

    root_name = if atom_name = @root_name
                  atom_name
                elsif @type.protein?
                  "CA"
                else
                  self.class.guess_root(atoms, bond_ts, link_bond)
                end

    Residue.new @names, @code, @type, @description,
      atoms, bond_ts, root_name, link_bond, @symmetric_atom_groups
  end

  def code(char : Char) : self
    @code = char
    self
  end

  private def check_atom(name : String) : Nil
    unless (parser = @spec_parser) && parser.atom_map[name]?
      raise "Unknown atom #{name}"
    end
  end

  def description(name : String) : self
    @description = name
    self
  end

  # Returns the atom with the highest bonding complexity.
  #
  # The bonding complexity of an atom depends on the nature of the atom,
  # the bonds, and the bonds of its neighbors.
  #
  # First, carbon atoms are the most frequent so they have the lowest
  # complexity (0), followed by non-carbon atoms (+1), and then
  # non-organic (not CHON) atoms (+2). Hydrogen atoms are ignored.
  #
  # The complexity is further increased by the number of bonds with
  # other heavy atoms, i.e., bonds X-H are ignored.
  #
  # The total complexity of an atom is computed as the sum of its
  # complexity and the complexities of the bonded atoms.
  def self.guess_root(
    atoms : Array(Atom),
    bonds : Array(Bond),
    link_bond : Bond?
  ) : String
    heavy_atoms = atoms.select &.element.heavy?
    return heavy_atoms[0].name unless heavy_atoms.size > 1

    complexity_table = heavy_atoms.to_h do |atom_t|
      complexity = case atom_t.element
                   when .carbon?             then 0
                   when .oxygen?, .nitrogen? then 1 # non-carbon
                   else                           2 # non-organic
                   end
      {atom_t, complexity}
    end

    bonded_table = {} of Atom => Array(Atom)
    bonds = bonds + [link_bond] if link_bond
    bonds.each do |bond_t|
      next unless bond_t.atoms.all?(&.element.heavy?) # ignore bonds X-H
      bond_t.atoms.each do |atom_t|
        (bonded_table[atom_t] ||= [] of Atom) << bond_t.other(atom_t)
        complexity_table[atom_t] += 1
      end
    end

    heavy_atoms.max_by do |atom_t|
      complexity_table[atom_t] +
        bonded_table[atom_t].sum { |other_t| complexity_table[other_t] }
    end.name
  end

  def type(type : ResidueType) : self
    @type = type
    self
  end

  def link_adjacent_by(bond_spec : String) : self
    parser = SpecParser.new(bond_spec)
    parser.parse
    if bond_r = parser.bonds[0]?
      @link_bond = {bond_r.lhs, bond_r.rhs, bond_r.order}
    else
      raise ParseException.new("Invalid link bond specification #{bond_spec.inspect}")
    end
    self
  end

  def name(*names : String) : self
    names names
    self
  end

  def names(*names : String) : self
    names names
    self
  end

  def names(names : Enumerable(String)) : self
    @names.concat names
    self
  end

  private def raise(msg : String)
    ::raise Error.new(msg)
  end

  def root(atom_name : String) : self
    check_atom atom_name
    @root_name = atom_name
    self
  end

  def spec(spec : String) : self
    raise "Residue structure already defined" if @spec_parser
    parser = SpecParser.new(spec, @spec_aliases)
    parser.parse
    raise "Empty structure" if parser.atom_map.empty?
    @spec_parser = parser
    self
  end

  def symmetry(*pairs : Tuple(String, String)) : self
    symmetry pairs
    self
  end

  def symmetry(pairs : Enumerable(Tuple(String, String))) : self
    visited = Set(String).new pairs.size * 2
    pairs.each do |(a, b)|
      check_atom(a)
      check_atom(b)
      raise "#{a} cannot be symmetric with itself" if a == b
      {a, b}.each do |name|
        raise "#{name} cannot be reassigned for symmetry" if name.in?(visited)
      end
      visited << a << b
    end
    @symmetric_atom_groups << pairs.to_a
    self
  end
end

# Generates hydrogen atom names much like an iterator.
private class HydrogenNameGenerator
  @global_counter = 0
  @names = Set(String).new

  # Returns the next numbered hydrogen name. Atom number is handle by an
  # internal global counter.
  def next : String
    until name = try("H#{@global_counter += 1}"); end
    @names << name
    name
  end

  # Returns the next numbered hydrogen name for the bonded atom
  # template.
  #
  # If *index* indicates the index of the current hydrogen. If `nil`, a
  # single hydrogen is being added.
  def next_for(atom_t : Chem::Templates::Atom, index : Int32?) : String
    non_carbon = !atom_t.element.carbon?
    if suffix = atom_t.suffix
      suffix = "#{suffix}#{index.try(&.succ)}"
      name = try "H#{suffix}"
      name ||= try "H#{atom_t.element.symbol}H#{suffix}" if non_carbon
      name ||= try "H#{suffix}1" if !index # singular
      @names << name if name
    end
    name || self.next
  end

  # Returns *name* if available, else `nil`.
  def try(name : String) : String?
    name unless name.in?(@names)
  end
end
