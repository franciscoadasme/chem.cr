module Chem::Topology::Templates
  class Builder
    class ParseException < Error; end

    ATOM_NAME_PATTERN  = "[A-Z]{1,2}[0-9]{0,2}"
    ATOM_SEP_REGEX     = /(?<=[A-Z0-9])#{BOND_ORDER_PATTERN}(?=[A-Z0-9])/
    ATOM_SPEC_REGEX    = /(#{ATOM_NAME_PATTERN})(\+|-)?(\((\d)\))?/
    BOND_ORDER_PATTERN = "[-=#]"
    BOND_REGEX         = /(#{ATOM_NAME_PATTERN})(#{BOND_ORDER_PATTERN})(#{ATOM_NAME_PATTERN})/

    @atom_types = [] of AtomType
    @bonds = [] of Bond
    @codes = [] of String
    @link_bond : Bond?
    @name : String?
    @symbol : Char?

    def initialize(@kind : Residue::Kind = :other)
    end

    def self.build(kind : Residue::Kind = :other) : Residue
      builder = Builder.new kind
      with builder yield
      builder.build
    end

    def backbone
      fatal "Backbone is only valid for protein residues" unless @kind.protein?
      fatal "Backbone must be added first" unless @atom_types.empty?
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
    end

    def branch(spec : String)
      check_root! "branch", spec
      parse_spec spec
    end

    def build : Residue
      fatal "Missing residue name" unless (name = @name)
      fatal "Missing residue code" if @codes.empty?
      fatal "Missing residue atom names" if @atom_types.empty?

      add_missing_hydrogens
      check_valences!

      Residue.new name, @codes.first, @symbol, @kind, @atom_types, @bonds, @link_bond
    end

    def code(code : String)
      @codes << code
    end

    def codes : Array(String)
      @codes.dup
    end

    def codes(*codes : String)
      @codes.concat codes
    end

    def cycle(spec : String)
      check_root! "cycle", spec
      spec += '-' unless /#{BOND_ORDER_PATTERN}$/ =~ spec
      parse_spec "#{spec}#{root spec}"
    end

    def link_adjacent_by(spec : String)
      @link_bond = parse_bond spec
    end

    def main(spec : String)
      spec = "CA-" + spec if @kind.protein?
      parse_spec spec
    end

    def name(name : String)
      @name = name
    end

    def remove_atom(atom_name : String)
      atom_t = atom_type! atom_name
      @bonds.reject! &.includes?(atom_t)
      @atom_types.delete atom_t
    end

    def sidechain
      fatal "Sidechain is only valid for protein residues" unless @kind.protein?
      fatal "Backbone must be added before sidechain" if @atom_types.empty?
      with self yield
    end

    def sidechain(spec : String)
      sidechain do
        main spec
      end
    end

    def symbol(char : Char) : Nil
      @symbol = char
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

    private def add_bond(atom_name : String, other : String, order : Int = 1)
      bond = @bonds.find { |bond| bond.includes?(atom_name) && bond.includes?(other) }
      if bond && bond.order != order
        fatal "Bond #{atom_name}#{bond.to_char}#{other} already exists"
      elsif bond.nil?
        @bonds << Bond.new atom_name, other, order
      end
    end

    private def add_bond(atom_t : AtomType, other : AtomType, order : Int = 1)
      add_bond atom_t.name, other.name, order
    end

    private def add_missing_hydrogens
      i = 0
      while i < @atom_types.size
        atom_t = @atom_types[i]
        h_count = missing_bonds atom_t
        h_count.times do |j|
          name = "H#{atom_t.suffix}#{j + 1 if h_count > 1}"
          pos = @atom_types.index(atom_t).not_nil! + 1 + j
          add_bond atom_t, atom_type(name, insert_at: pos)
          i += 1
        end

        i += 1
      end
    end

    private def check_root!(cmd : String, desc : String)
      atom_name = root desc
      return if atom_type? atom_name
      parse_exception "#{cmd.capitalize} must start with an existing atom type, " \
                      "got #{atom_name}"
    end

    private def check_valences!
      @atom_types.each do |atom_t|
        count = missing_bonds atom_t
        next if count == 0
        name = atom_t.name
        name += (atom_t.formal_charge > 0 ? '+' : '-') if atom_t.formal_charge != 0
        fatal "atom type #{name} has incorrect valence (#{atom_t.valence - count}), " \
              "expected #{atom_t.valence}"
      end
    end

    private def fatal(msg)
      raise Error.new msg
    end

    private def missing_bonds(atom_t : AtomType) : Int32
      valence = atom_t.valence
      if bond = @link_bond
        valence -= bond.order if bond.includes?(atom_t)
      end
      valence - @bonds.each.select(&.includes?(atom_t.name)).map(&.order).sum
    end

    private def parse_atom(spec : String) : AtomType
      if spec =~ ATOM_SPEC_REGEX
        atom_type name: $~[1],
          formal_charge: parse_charge($~[2]?),
          valence: $~[4]?.try(&.to_i)
      else
        parse_exception "Invalid atom specification \"#{spec}\""
      end
    end

    private def parse_bond(spec : String)
      if spec =~ BOND_REGEX
        _, atom_name, bond_str, other = $~
        atom_type! atom_name
        atom_type! other
        Bond.new atom_name, other, parse_bond_order(bond_str[0])
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
      return 0 unless spec
      spec == "+" ? 1 : -1
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

    private def root(spec : String) : String
      spec[/#{ATOM_NAME_PATTERN}/]
    end
  end
end
