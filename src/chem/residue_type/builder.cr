class Chem::ResidueType::Builder
  @code : Char?
  @description : String?
  @kind : Residue::Kind = :other
  @link_bond : Tuple(String, String, Int32)?
  @names = [] of String
  @root_atom : String?
  @symmetric_atom_groups = [] of Array(Tuple(String, String))
  @structure_parser : Parser?

  private def add_hydrogens
    use_name_suffix = @atom_types.any? &.suffix.to_i?.nil?
    atom_types = use_name_suffix ? @atom_types : @atom_types.sort_by do |atom_t|
      {atom_t.element.atomic_number * -1, atom_t.suffix.to_i}
    end

    h_i = 0
    atom_types.each do |atom_type|
      i = @atom_types.index! atom_type

      # TODO: implement a sane valence model, e.g., smiles model in openbabel
      bond_count = @bonds.sum { |bond| atom_type.in?(bond) ? bond.order : 0 }
      if bond = @link_bond
        bond_count += bond.order if atom_type.in?(bond)
      end
      bond_count += @implicit_bonds[atom_type.name]? || 0

      valency = atom_type.element.valencies.find(&.>=(bond_count))
      valency ||= atom_type.element.max_valency
      valency += atom_type.element.ionic? ? -atom_type.formal_charge.abs : atom_type.formal_charge

      h_count = valency - bond_count
      if h_count >= 0
        h_count.times do |j|
          h_i += 1
          name = use_name_suffix ? "H#{atom_type.suffix}#{j + 1 if h_count > 1}" : "H#{h_i}"
          h_atom = AtomType.new(name, element: PeriodicTable::H)
          @atom_types.insert i + 1 + j, h_atom
          @bonds << BondType.new(atom_type, h_atom)
        end
      else
        raise Error.new("Expected valency of #{atom_type.name} is #{valency}, \
                         got #{bond_count}")
      end
    end
  end

  protected def build : ResidueType
    raise Error.new("Missing residue name") if @names.empty?
    raise Error.new("Empty structure") unless parser = @structure_parser

    if @kind.protein? && {"C", "N", "CA"}.none? { |name| parser.atom_map[name]? }
      raise Error.new("Missing backbone atoms for #{@names.first}")
    end
    @link_bond ||= case @kind
                   when .protein? then {"C", "N", 1}
                   end

    implicit_bonds = Hash(String, Int32).new { 0 }
    parser.implicit_bonds.each do |bond|
      implicit_bonds[bond.lhs] += bond.order
    end

    atom_types = [] of AtomType
    atom_type_map = {} of String => AtomType
    bond_types = [] of BondType
    h_i = 0
    parser.atom_map.each_value do |atom|
      element = atom.element || PeriodicTable[atom_name: atom.name]

      effective_valence = atom.explicit_hydrogens || 0
      effective_valence += atom.formal_charge * (element.valence_electrons >= 4 ? -1 : 1)
      effective_valence += parser.bonds.sum do |bond|
        atom.name.in?(bond.lhs, bond.rhs) ? bond.order : 0
      end
      effective_valence += implicit_bonds[atom.name]? || 0
      if bond = @link_bond
        effective_valence += bond[2] if atom.name.in?(bond)
      end

      target_valence = element.valence(effective_valence)
      if effective_valence > target_valence ||
         (atom.explicit_hydrogens && effective_valence != target_valence)
        raise Error.new("Expected valence of #{atom.name} is #{target_valence}, \
                         got #{effective_valence}")
      end

      atom_type = AtomType.new(atom.name, element, target_valence, atom.formal_charge)
      atom_types << atom_type
      atom_type_map[atom_type.name] = atom_type

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

    link_bond = @link_bond.try do |lhs, rhs, order|
      BondType.new(atom_type_map[lhs], atom_type_map[rhs], order)
    end
    root_atom = if atom_name = @root_atom
                  atom_type_map[atom_name]
                elsif @kind.protein?
                  atom_type_map["CA"]
                elsif atom_types.count(&.element.heavy?) == 1
                  atom_types.first
                else
                  raise Error.new("Missing root for residue type #{@names.first}")
                end

    ResidueType.new @names.first, @code, @kind, @description,
      atom_types, bond_types, root_atom,
      @names[1..], link_bond, @symmetric_atom_groups
  end

  def code(char : Char) : Nil
    @code = char
  end

  private def check_atom(name : String) : Parser::AtomRecord
    if (parser = @structure_parser) && (atom = parser.atom_map[name]?)
      atom
    else
      raise Error.new("Unknown atom #{name}")
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
                 when "-" then 1
                 when "=" then 2
                 when "#" then 3
                 else          raise "BUG: unreachable"
                 end
    @link_bond = {lhs, rhs, bond_order}
  end

  def name(*names : String)
    @names.concat names
  end

  def root(atom_name : String)
    check_atom atom_name
    @root_atom = atom_name
  end

  def structure(spec : String, aliases : Hash(String, String)? = nil) : Nil
    raise Error.new("Residue structure already defined") if @structure_parser
    parser = ResidueType::Parser.new(spec, aliases)
    parser.parse
    raise Error.new("Empty structure") if parser.atom_map.empty?
    @structure_parser = parser
  end

  def symmetry(*pairs : Tuple(String, String)) : Nil
    visited = Set(String).new pairs.size * 2
    pairs.each do |(a, b)|
      check_atom(a)
      check_atom(b)
      raise Error.new("#{a} cannot be symmetric with itself") if a == b
      {a, b}.each do |name|
        raise Error.new("#{name} cannot be reassigned for symmetry") if name.in?(visited)
      end
      visited << a << b
    end
    @symmetric_atom_groups << pairs.to_a
  end
end
