class Chem::ResidueType::Builder
  @atom_types = [] of AtomType
  @bonds = [] of BondType
  @code : Char?
  @description : String?
  @kind : Residue::Kind = :other
  @link_bond : BondType?
  @names = [] of String
  @root_atom : AtomType?
  @symmetric_atom_groups = [] of Array(Tuple(String, String))

  private def add_hydrogens
    use_name_suffix = @atom_types.any? &.suffix.to_i?.nil?
    atom_types = use_name_suffix ? @atom_types : @atom_types.sort_by do |atom_t|
      {atom_t.element.atomic_number * -1, atom_t.suffix.to_i}
    end

    h_i = 0
    atom_types.each do |atom_t|
      i = @atom_types.index! atom_t
      h_count = missing_bonds_of(atom_t)
      h_count.times do |j|
        h_i += 1
        name = use_name_suffix ? "H#{atom_t.suffix}#{j + 1 if h_count > 1}" : "H#{h_i}"
        atom_type = AtomType.new(name, element: PeriodicTable::H)
        @atom_types.insert i + 1 + j, atom_type
        @bonds << BondType.new(atom_t, atom_type)
      end
    end
  end

  protected def build : ResidueType
    raise Error.new("Missing residue name") if @names.empty?

    raise Error.new("No atoms for residue type") if @atom_types.empty?
    raise Error.new("No bonds for residue type") if @atom_types.size > 1 && @bonds.empty?

    @link_bond ||= BondType.new(check_atom_type("C"), check_atom_type("N")) if @kind.protein?
    add_hydrogens
    check_valencies

    @root_atom ||= if @kind.protein?
                     check_atom_type("CA")
                   elsif @atom_types.count { |a| !a.element.hydrogen? } == 1
                     @atom_types[0]
                   end
    raise Error.new("Missing root for residue type #{@names[0]}") unless root_atom = @root_atom

    ResidueType.new @names.first, @code, @kind, @description,
      @atom_types, @bonds, root_atom,
      @names[1..], @link_bond, @symmetric_atom_groups
  end

  def code(char : Char) : Nil
    @code = char
  end

  private def check_atom_type(name : String) : AtomType
    if atom_type = @atom_types.find(&.name.==(name))
      atom_type
    else
      raise Error.new("Unknown atom type #{name}")
    end
  end

  # private def check_valencies
  #   @atom_types.each do |atom_t|
  #     bond_count = missing_bonds_of(atom_t)
  #     if bond_count > 0
  #       raise Error.new(
  #         "Atom type #{atom_t} has incorrect valency (#{valency}), \
  #          expected #{atom_t.valency}")
  #     end
  #   end
  # end

  private def check_valencies
    @atom_types.each do |atom_t|
      num = missing_bonds_of atom_t
      next if num == 0
      raise Error.new(
        "Atom type #{atom_t} has incorrect valency (#{atom_t.valency - num}), " \
        "expected #{atom_t.valency}")
    end
  end

  def description(name : String)
    @description = name
  end

  def kind(kind : Residue::Kind)
    @kind = kind
  end

  def link_adjacent_by(bond_spec : String)
    lhs, bond_str, rhs = bond_spec.partition(/[-=#]/)
    raise ParseException.new("Invalid bond") if bond_str.empty? || rhs.empty?
    lhs = check_atom_type(lhs)
    rhs = check_atom_type(rhs)
    raise ParseException.new("Atom #{lhs} cannot be bonded to itself") if lhs == rhs
    bond_order = case bond_str
                 when "-" then 1
                 when "=" then 2
                 when "#" then 3
                 else          raise "BUG: unreachable"
                 end
    @link_bond = BondType.new lhs, rhs, bond_order
  end

  # private def missing_bonds_of(atom_type : AtomType) : Int32
  #   bond_order = @bonds.sum { |bond| atom_type.name.in?(bond) ? bond.order : 0 }
  #   if bond = @link_bond
  #     bond_order += bond.order if atom_type.in?(bond)
  #   end
  #   nominal_valency = atom_type.element.valencies.find(&.>=(bond_order))
  #   nominal_valency ||= atom_type.element.max_valency
  #   # NOTE: why `+ formal_charge`?
  #   bound_count = nominal_valency - bond_order + atom_type.formal_charge
  #   raise "BUG: negative bond count for #{atom_type}" if bound_count < 0
  #   bound_count
  # end

  private def missing_bonds_of(atom_t : AtomType) : Int32
    valency = atom_t.valency
    if bond = @link_bond
      valency -= bond.order if atom_t.in?(bond)
    end
    valency - @bonds.each.select(&.includes?(atom_t.name)).map(&.order).sum
  end

  def name(*names : String)
    @names.concat names
  end

  def root(atom_name : String)
    @root_atom = check_atom_type atom_name
  end

  def structure(spec : String, aliases : Hash(String, String)? = nil) : Nil
    parser = ResidueType::Parser.new(spec, aliases)
    parser.parse
    @atom_types = parser.atom_types
    @bonds = parser.bond_types
  end

  def symmetry(*pairs : Tuple(String, String)) : Nil
    visited = Set(String).new pairs.size * 2
    pairs.each do |(a, b)|
      check_atom_type(a)
      check_atom_type(b)
      raise Error.new("#{a} cannot be symmetric with itself") if a == b
      {a, b}.each do |name|
        raise Error.new("#{name} cannot be reassigned for symmetry") if name.in?(visited)
      end
      visited << a << b
    end
    @symmetric_atom_groups << pairs.to_a
  end
end
