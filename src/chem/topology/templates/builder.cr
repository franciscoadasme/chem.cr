module Chem::Topology::Templates
  class Builder
    class ParseException < Error; end

    ATOM_NAME_PATTERN  = "[A-Z]{1,3}[0-9]{0,2}"
    ATOM_SEP_REGEX     = /(?<=[A-Z0-9\)\]])#{BOND_ORDER_PATTERN}(?=[A-Z0-9])/
    ATOM_SPEC_REGEX    = /(#{ATOM_NAME_PATTERN})(\[([A-Z][a-z]?)\])?([\+-]\d?)?(\((\d)\))?/
    BOND_ORDER_PATTERN = "[-=#]"
    BOND_REGEX         = /(#{ATOM_NAME_PATTERN})(#{BOND_ORDER_PATTERN})(#{ATOM_NAME_PATTERN})/

    @atom_types = [] of AtomType
    @bonds = [] of BondType
    @names = [] of String
    @link_bond : BondType?
    @description : String?
    @root : AtomType?
    @code : Char?

    def initialize(@kind : Residue::Kind = :other)
      setup
    end

    def self.build(kind : Residue::Kind = :other) : ResidueType
      builder = Builder.new kind
      with builder yield
      builder.build
    end

    def branch(spec : String)
      check_root! "branch", spec
      parse_spec spec
    end

    def build : ResidueType
      fatal "Missing residue description" unless (description = @description)
      fatal "Missing residue name" if @names.empty?
      fatal "Missing residue atom names" if @atom_types.empty?

      add_missing_hydrogens
      check_valencies!

      ResidueType.new description, @names.first, @code, @kind, @atom_types, @bonds,
        @link_bond, @root
    end

    def name(name : String)
      @names << name
    end

    def names : Array(String)
      @names.dup
    end

    def names(*names : String)
      @names.concat names
    end

    def cycle(spec : String)
      check_root! "cycle", spec
      spec += '-' unless /#{BOND_ORDER_PATTERN}$/ =~ spec
      parse_spec "#{spec}#{extract_root spec}"
    end

    def link_adjacent_by(spec : String)
      @link_bond = parse_bond spec
    end

    def main(spec : String)
      spec = "CA-" + spec if @kind.protein?
      parse_spec spec
    end

    def description(name : String)
      @description = name
    end

    def remove_atom(atom_name : String)
      atom_t = atom_type! atom_name
      @bonds.reject! &.includes?(atom_t)
      @atom_types.delete atom_t
    end

    def root(atom_name : String)
      @root = atom_type! atom_name
    end

    def sidechain
      fatal "Sidechain is only valid for protein residues" unless @kind.protein?
      with self yield
    end

    def sidechain(spec : String)
      sidechain do
        main spec
      end
    end

    def code(char : Char) : Nil
      @code = char
    end

    private def atom_type(name : String,
                          *,
                          insert_at pos : Int32 = -1,
                          **options) : AtomType?
      atom_type = atom_type?(name)
      unless atom_type
        atom_type = AtomType.new name, **options
        if @atom_types.empty?
          @atom_types << atom_type
        else
          @atom_types.insert pos, atom_type
        end
      end
      atom_type
    end

    private def atom_type?(name : String) : AtomType?
      @atom_types.find &.name.==(name)
    end

    private def atom_type!(name : String) : AtomType
      atom_type?(name) || fatal "Unknown atom type #{name}"
    end

    private def add_bond(atom_t : AtomType, other : AtomType, order : Int = 1)
      bond = @bonds.find { |bond| atom_t.in?(bond) && other.in?(bond) }
      if bond && bond.order != order
        fatal "Bond #{atom_t.name}#{bond.to_char}#{other.name} already exists"
      elsif bond.nil?
        @bonds << BondType.new atom_t, other, order
      end
    end

    private def add_bond(atom_name : String, other : String, order : Int = 1)
      add_bond atom_type(atom_name), atom_type(other), order
    end

    private def add_missing_hydrogens
      use_name_suffix = @atom_types.any? &.suffix.to_i?.nil?
      atom_types = use_name_suffix ? @atom_types : @atom_types.sort_by do |atom_t|
        {atom_t.element.atomic_number * -1, atom_t.suffix.to_i}
      end

      h_i = 0
      atom_types.each do |atom_t|
        i = @atom_types.index! atom_t
        h_count = missing_bonds atom_t
        h_count.times do |j|
          h_i += 1
          name = use_name_suffix ? "H#{atom_t.suffix}#{j + 1 if h_count > 1}" : "H#{h_i}"
          add_bond atom_t, atom_type(name, element: "H", insert_at: i + 1 + j)
        end
      end
    end

    private def check_root!(cmd : String, desc : String)
      atom_name = extract_root desc
      return if atom_type? atom_name
      parse_exception "#{cmd.capitalize} must start with an existing atom type, " \
                      "got #{atom_name}"
    end

    private def check_valencies!
      @atom_types.each do |atom_t|
        num = missing_bonds atom_t
        next if num == 0
        fatal "Atom type #{atom_t} has incorrect valency (#{atom_t.valency - num}), " \
              "expected #{atom_t.valency}"
      end
    end

    private def extract_root(spec : String) : String
      spec[/#{ATOM_NAME_PATTERN}/]
    end

    private def fatal(msg)
      raise Error.new msg
    end

    private def missing_bonds(atom_t : AtomType) : Int32
      valency = atom_t.valency
      if bond = @link_bond
        valency -= bond.order if atom_t.in?(bond)
      end
      valency - @bonds.each.select(&.includes?(atom_t.name)).map(&.order).sum
    end

    private def parse_atom(spec : String) : AtomType
      if spec =~ ATOM_SPEC_REGEX
        atom_type name: $~[1],
          element: $~[3]?,
          formal_charge: parse_charge($~[4]?),
          valency: $~[6]?.try(&.to_i)
      else
        parse_exception "Invalid atom specification \"#{spec}\""
      end
    end

    private def parse_bond(spec : String)
      if spec =~ BOND_REGEX
        _, lhs, bond_str, rhs = $~
        BondType.new atom_type!(lhs), atom_type!(rhs), parse_bond_order(bond_str[0])
      else
        parse_exception "Invalid bond specification \"#{spec}\""
      end
    end

    private def parse_bond_order(char : Char) : Int32
      case char
      when '-' then 1
      when '=' then 2
      when '#' then 3
      else          parse_exception "Unknown bond order \"#{char}\""
      end
    end

    private def parse_charge(spec : String?) : Int32
      case spec
      when "+"    then 1
      when "-"    then -1
      when String then spec.to_i
      else             0
      end
    end

    private def parse_exception(msg : String)
      raise ParseException.new msg
    end

    private def parse_spec(spec : String) : Nil
      atom_specs = spec.split ATOM_SEP_REGEX
      bond_chars = spec.scan(ATOM_SEP_REGEX).map(&.[0]).map &.[0]
      parse_exception "Invalid specification" if bond_chars.size != atom_specs.size - 1

      atom_types = atom_specs.map { |spec| parse_atom spec }
      bond_chars.each_with_index do |bond_char, i|
        add_bond atom_types[i], atom_types[i + 1], parse_bond_order(bond_char)
      end
    end

    private def setup
      case @kind
      when .protein?
        atom_type "N"
        atom_type "H"
        atom_type "CA"
        atom_type "HA"
        atom_type "C"
        atom_type "O"
        parse_spec "N-CA-C=O"
        add_bond "N", "H"
        add_bond "CA", "HA"
        link_adjacent_by "C-N"
        root "CA"
      end
    end
  end
end
