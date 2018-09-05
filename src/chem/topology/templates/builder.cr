module Chem::Topology::Templates
  class Builder
    class ParseException < Error; end

    struct AtomInfo
      getter name : String
      getter formal_charge : Int32
      getter valence : Int32

      def initialize(@name : String, @formal_charge : Int32, valence : Int32? = nil)
        @valence = valence || nominal_valence
      end

      def suffix : String
        element = PeriodicTable.element atom_name: name
        name[element.symbol.size..-1]
      end

      private def nominal_valence : Int32
        element = PeriodicTable.element(atom_name: name)
        element.valence + @formal_charge
      end
    end

    ATOM_NAME_REGEX = /(?<name>[A-Z]{1,2}[0-9]{0,2})(?<charge>\+|-)?(\((?<valence>\d)\))?/
    BOND_SEP        = /(?<=[A-Z0-9])[-=#@](?=[A-Z0-9])/

    @atoms : Array(AtomInfo)
    @bonds : Array(Bond)
    @code : String?
    @name : String?
    @kind : Kind = :other
    @symbol : Char?

    def initialize
      @atoms = [] of AtomInfo
      @bonds = [] of Bond
    end

    def self.build : Residue
      builder = Builder.new
      with builder yield
      builder.build
    end

    def backbone : Nil
      fatal "backbone must be added first" unless @atoms.empty?
      kind :protein
      parse_bonds "N-CA-C=O"
      add_bond "-C", "N"
      add_bond "C", "-CA"
    end

    def branch(desc : String) : Nil
      check_root "branch", desc
      parse_bonds desc
    end

    def build : Residue
      fatal "missing residue name" unless @name
      fatal "missing residue code" unless @code
      fatal "missing residue symbol" unless @symbol
      fatal "missing residue atom names" if @atoms.empty?
      fatal "missing residue bonds" if @bonds.empty?

      add_missing_hydrogens
      check_valences

      Residue.new @name.not_nil!, @code.not_nil!, @symbol.not_nil!, @kind,
        @atoms.map(&.name), @atoms.map(&.formal_charge), @bonds
    end

    def code(code : String) : Nil
      @code = code
    end

    def cycle(desc : String) : Nil
      check_root "cycle", desc
      root = desc[/[A-Z0-9]+/]
      desc += '-' unless /[-=#@]$/ =~ desc
      parse_bonds "#{desc}#{root}"
    end

    def kind(kind : Kind) : Nil
      @kind = kind
    end

    def main(bond_spec : String) : Nil
      bond_spec = "CA-" + bond_spec if @kind == Kind::Protein
      parse_bonds bond_spec
    end

    def name(name : String) : Nil
      @name = name
    end

    def remove_atom(name : String) : Nil
      if atom = @atoms.find { |at| at.name == name }
        @bonds.each.select(&.has_atom?(atom.not_nil!.name)).each do |bond|
          @bonds.delete bond
        end
        @atoms.delete atom
      end
    end

    def sidechain : Nil
      raise Error.new "missing backbone" if @kind != Kind::Protein && @atoms.empty?
      with self yield
    end

    def sidechain(desc : String) : Nil
      sidechain do
        main desc
      end
    end

    def symbol(symbol : Char) : Nil
      @symbol = symbol
    end

    private def add_bond(atom1 : String, atom2 : String, order : Bond::Order = :single) : Nil
      bond = @bonds.find { |bond| bond.has_atom?(atom1) && bond.has_atom?(atom2) }
      if bond && bond.order != order
        fatal "bond #{atom1}-#{atom2} already exists with a different order"
      elsif bond.nil?
        @bonds << Bond.new atom1, atom2, order
      end
    end

    private def add_missing_hydrogens : Nil
      i = 0
      while i < @atoms.size
        atom = @atoms[i]
        h_count = missing_valence atom
        h_count.times do |i|
          name = "H#{atom.suffix}#{i + 1 if h_count > 1}"
          h_atom = AtomInfo.new(name, formal_charge: 0, valence: 1)
          @atoms.insert @atoms.index(atom).not_nil! + 1 + i, h_atom
          add_bond atom.name, h_atom.name
          i += 1
        end

        i += 1
      end
    end

    private def check_root(name : String, desc : String) : Nil
      root = desc[/[A-Z0-9]+/]
      unless @atoms.find { |atom| atom.name == root }
        parse_exception "#{name} must start with an existing atom name"
      end
    end

    private def check_valences : Nil
      @atoms.each do |atom|
        next if missing_valence(atom) == 0
        valence = current_valence of: atom
        name = atom.name
        name += (atom.formal_charge > 0 ? '+' : '-') if atom.formal_charge != 0
        fatal "atom #{name} has incorrect valence (#{valence}), expected #{atom.valence}"
      end
    end

    private def current_valence(of atom : AtomInfo) : Int32
      @bonds.each.select(&.has_atom?(atom.name)).map(&.order.to_i).sum
    end

    private def fatal(msg)
      raise Error.new msg
    end

    private def missing_valence(atom : AtomInfo) : Int32
      atom.valence - current_valence(of: atom)
    end

    private def parse_bond_order(spec : Char) : Bond::Order
      case spec
      when '-' then Bond::Order::Single
      when '=' then Bond::Order::Double
      when '#' then Bond::Order::Triple
      when '@' then Bond::Order::Aromatic
      else          parse_exception "unknown bond order: #{spec}"
      end
    end

    private def parse_atom(desc : String) : AtomInfo
      parse_exception "invalid atom description #{desc}" unless ATOM_NAME_REGEX =~ desc

      AtomInfo.new $~["name"],
        formal_charge: parse_charge($~["charge"]?),
        valence: $~["valence"]?.try(&.to_i)
    end

    private def parse_bonds(desc : String) : Nil
      atoms = desc.split BOND_SEP
      bonds = desc.scan(BOND_SEP).map(&.[0]).map &.[0]
      parse_exception "invalid bond specification" if bonds.size != atoms.size - 1

      atoms = atoms.map { |desc| parse_atom desc }
      atoms.each { |atom| @atoms << atom unless @atoms.includes? atom }
      bonds.each_with_index do |bond_str, i|
        add_bond atoms[i].name, atoms[i + 1].name, parse_bond_order(bond_str)
      end
    end

    private def parse_charge(desc : String?) : Int32
      return 0 unless desc
      desc == "+" ? 1 : -1
    end

    private def parse_exception(msg : String)
      raise ParseException.new msg
    end
  end
end
