class Chem::ResidueTemplate::Builder
  @code : Char?
  @description : String?
  @kind : Residue::Kind = :other
  @link_bond : Tuple(String, String, BondOrder)?
  @names = [] of String
  @root_atom : String?
  @symmetric_atom_groups = [] of Array(Tuple(String, String))
  @structure_parser : Parser?

  def build : ResidueTemplate
    raise "Missing residue name" if @names.empty?
    raise "Empty structure" unless parser = @structure_parser
    if @kind.protein? && {"C", "N", "CA"}.none? { |name| parser.atom_map[name]? }
      raise "Missing backbone atoms for #{@names.first}"
    end

    # Set link bond if missing for known residue templates
    @link_bond ||= case @kind
                   when .protein? then {"C", "N", BondOrder::Single}
                   end

    # Count total of implicit bonds per atom
    implicit_bonds = Hash(String, Int32).new { 0 }
    parser.implicit_bonds.each do |bond|
      implicit_bonds[bond.lhs] += bond.order.to_i
    end

    atom_types = [] of AtomType
    atom_type_map = {} of String => AtomType
    bond_types = [] of BondType
    h_i = 0
    parser.atom_map.each_value do |atom|
      element = atom.element || Topology.guess_element(atom.name)

      # Calculate effective valence
      effective_valence = atom.explicit_hydrogens || 0
      effective_valence += atom.formal_charge * (element.valence_electrons >= 4 ? -1 : 1)
      effective_valence += parser.bonds.sum do |bond| # sum of bond orders
        atom.name.in?(bond.lhs, bond.rhs) ? bond.order.to_i : 0
      end
      effective_valence += implicit_bonds[atom.name]? || 0
      if bond = @link_bond
        effective_valence += bond[2].to_i if atom.name.in?(bond)
      end

      # Check that effective valence is correct
      target_valence = element.target_valence(effective_valence)
      if effective_valence > target_valence ||
         (atom.explicit_hydrogens && effective_valence != target_valence)
        raise "Expected valence of #{atom.name} is #{target_valence}, \
               got #{effective_valence}"
      end

      # Create and register atom type
      atom_type = AtomType.new(atom.name, element, target_valence, atom.formal_charge)
      atom_types << atom_type
      atom_type_map[atom_type.name] = atom_type

      # Add hydrogens (either explicit or implicit)
      suffix = atom_type.suffix.presence
      suffix = nil if suffix && suffix.size == 1 && suffix[0].ascii_number?
      h_count = atom.explicit_hydrogens || (target_valence - effective_valence)
      h_count.times do |i|
        name = suffix ? "H#{suffix}#{i + 1 if h_count > 1}" : "H#{h_i += 1}"
        h_atom = AtomType.new(name, PeriodicTable::H, valence: 1)
        atom_types << h_atom
        bond_types << BondType.new(atom_type, h_atom)
      end
    end

    parser.bonds.each do |bond|
      bond_types << BondType.new(
        atom_type_map[bond.lhs],
        atom_type_map[bond.rhs],
        bond.order)
    end

    # Get root atom or sets it for known residue templates if missing,
    # otherwise raise
    root_atom = if atom_name = @root_atom
                  atom_type_map[atom_name]
                elsif @kind.protein?
                  atom_type_map["CA"]
                elsif atom_types.count(&.element.heavy?) == 1 # one heavy atom
                  atom_types.first
                else
                  raise "Missing root for residue template #{@names.first}"
                end
    link_bond = @link_bond.try do |lhs, rhs, order|
      BondType.new(atom_type_map[lhs], atom_type_map[rhs], order)
    end

    ResidueTemplate.new @names.first, @code, @kind, @description,
      atom_types, bond_types, root_atom,
      @names[1..], link_bond, @symmetric_atom_groups
  end

  def code(char : Char) : Nil
    @code = char
  end

  private def check_atom(name : String) : Nil
    unless (parser = @structure_parser) && parser.atom_map[name]?
      raise "Unknown atom #{name}"
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
    check_atom(lhs)
    check_atom(rhs)
    raise ParseException.new("Atom #{lhs} cannot be bonded to itself") if lhs == rhs
    bond_order = case bond_str
                 when "-" then BondOrder::Single
                 when "=" then BondOrder::Double
                 when "#" then BondOrder::Triple
                 else          ::raise "BUG: unreachable"
                 end
    @link_bond = {lhs, rhs, bond_order}
  end

  def name(*names : String)
    @names.concat names
  end

  private def raise(msg : String)
    ::raise Error.new(msg)
  end

  def root(atom_name : String)
    check_atom atom_name
    @root_atom = atom_name
  end

  def structure(spec : String, aliases : Hash(String, String)? = nil) : Nil
    raise "Residue structure already defined" if @structure_parser
    parser = ResidueTemplate::Parser.new(spec, aliases)
    parser.parse
    raise "Empty structure" if parser.atom_map.empty?
    @structure_parser = parser
  end

  def symmetry(*pairs : Tuple(String, String)) : Nil
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
  end
end
