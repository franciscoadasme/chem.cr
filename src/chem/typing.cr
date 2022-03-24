module Chem
  class AtomType
    getter element : Element
    getter formal_charge : Int32
    getter name : String
    getter valency : Int32

    def initialize(@name : String,
                   @formal_charge : Int32 = 0,
                   element : String? = nil,
                   valency : Int32? = nil)
      @element = element ? PeriodicTable[element] : PeriodicTable[atom_name: name]
      @valency = valency || nominal_valency
    end

    def inspect(io : IO) : Nil
      io << "<AtomType "
      to_s io
      io << '>'
    end

    def suffix : String
      name[@element.symbol.size..]
    end

    def to_s(io : IO)
      io << @name
      io << '(' << @valency << ')' unless @valency == nominal_valency
      io << (@formal_charge > 0 ? '+' : '-') unless @formal_charge == 0
      io << @formal_charge.abs if @formal_charge.abs > 1
    end

    private def nominal_valency : Int32
      # FIXME: this is completely wrong. N+ and Mg2+ behave differently.
      valency = @element.max_valency
      valency += @element.ionic? ? -@formal_charge.abs : @formal_charge
      valency
    end
  end

  class BondType
    include Indexable(AtomType)

    getter order : Int32
    delegate size, unsafe_fetch, to: @atoms

    @atoms : StaticArray(AtomType, 2)

    def initialize(lhs : AtomType, rhs : AtomType, @order : Int = 1)
      @atoms = StaticArray[lhs, rhs]
    end

    def self.new(lhs : String, rhs : String, order : Int = 1) : self
      BondType.new AtomType.new(lhs), AtomType.new(rhs), order
    end

    def ==(rhs : self) : Bool
      return false if @order != rhs.order
      (self[0] == rhs[0] && self[1] == rhs[1]) ||
        (self[0] == rhs[1] && self[1] == rhs[0])
    end

    def double? : Bool
      @order == 2
    end

    def includes?(name : String) : Bool
      any? &.name.==(name)
    end

    def includes?(atom_type : AtomType) : Bool
      any? &.name.==(atom_type.name)
    end

    def inspect(io : IO) : Nil
      io << "<BondType "
      to_s io
      io << '>'
    end

    def inverse : self
      BondType.new self[1], self[0], @order
    end

    def other(atom_t : AtomType) : AtomType
      case atom_t
      when self[0]
        self[1]
      when self[1]
        self[0]
      else
        raise ArgumentError.new("Cannot find atom type #{atom_t}")
      end
    end

    def other(name : String) : AtomType
      case name
      when self[0].name
        self[1]
      when self[1].name
        self[0]
      else
        raise ArgumentError.new("Cannot find atom type named #{name}")
      end
    end

    def single? : Bool
      @order == 1
    end

    def to_s(io : IO) : Nil
      bond_char = case @order
                  when 1 then '-'
                  when 2 then '='
                  when 3 then '#'
                  else        raise "BUG: unreachable"
                  end
      io << self[0].name << bond_char << self[1].name
    end

    def triple? : Bool
      @order == 3
    end
  end

  class ResidueType
    private REGISTRY = {} of String => ResidueType

    @atom_types : Array(AtomType)
    @bonds : Array(BondType)

    getter name : String
    getter aliases : Array(String)
    getter kind : Residue::Kind
    getter link_bond : BondType?
    getter description : String
    getter root_atom : AtomType
    getter code : Char?
    getter symmetric_atom_groups : Array(Array(Tuple(String, String)))?

    def initialize(
      @name : String,
      @code : Char?,
      @kind : Residue::Kind,
      @description : String,
      atom_types : Array(AtomType),
      bonds : Array(BondType),
      @root_atom : AtomType,
      @aliases : Array(String) = [] of String,
      @link_bond : BondType? = nil,
      @symmetric_atom_groups : Array(Array(Tuple(String, String)))? = nil
    )
      @atom_types = atom_types.dup
      @bonds = bonds.dup
    end

    def self.all_types : Array(ResidueType)
      REGISTRY.values
    end

    def self.build : self
      builder = ResidueType::Builder.new
      with builder yield builder
      builder.build
    end

    def self.fetch(name : String) : ResidueType
      fetch(name) { raise Error.new("Unknown residue type #{name}") }
    end

    def self.fetch(name : String, & : -> T) : ResidueType | T forall T
      REGISTRY[name]? || yield
    end

    def self.register : ResidueType
      ResidueType.build do |builder|
        with builder yield builder
        residue = builder.build
        ([residue.name] + residue.aliases).each do |name|
          raise Error.new("#{name} residue type already exists") if REGISTRY.has_key?(name)
          REGISTRY[name] = residue
        end
      end
    end

    def [](atom_name : String) : AtomType
      self[atom_name]? || raise Error.new "Unknown atom type #{atom_name}"
    end

    def []?(atom_name : String) : AtomType?
      @atom_types.find &.name.==(atom_name)
    end

    def atom_count(*, include_hydrogens : Bool = true)
      size = @atom_types.size
      size -= @atom_types.count &.element.hydrogen? unless include_hydrogens
      size
    end

    def atom_names : Array(String)
      @atom_types.map &.name
    end

    def atom_types : Array(AtomType)
      @atom_types.dup
    end

    def each_atom_type(&block : AtomType ->)
      @atom_types.each &block
    end

    def bonded_atoms(atom_t : AtomType) : Array(AtomType)
      @bonds.select(&.includes?(atom_t)).map &.other(atom_t)
    end

    def bonds : Array(BondType)
      @bonds.dup
    end

    def formal_charge : Int32
      @atom_types.each.map(&.formal_charge).sum
    end

    def inspect(io : IO) : Nil
      io << "<ResidueType " << @name
      io << '(' << @code << ')' if @code
      io << ", " << @kind.to_s.downcase unless @kind.other?
      io << '>'
    end

    def monomer? : Bool
      !link_bond.nil?
    end

    def n_atoms : Int32
      @atom_types.size
    end
  end

  class ResidueType::Builder
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
          atom_type = AtomType.new(name, element: "H")
          @atom_types.insert i + 1 + j, atom_type
          @bonds << BondType.new(atom_t, atom_type)
        end
      end
    end

    def aliases(*names : String)
      raise Error.new("Aliases cannot be set for unnamed residue type") if @names.empty?
      @names.concat names
    end

    protected def build : ResidueType
      raise Error.new("Missing residue description") unless (description = @description)
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

      ResidueType.new @names.first, @code, @kind, description,
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

    def name(name : String)
      @names << name
    end

    def root(atom_name : String)
      @root_atom = check_atom_type atom_name
    end

    def structure(spec : String) : Nil
      {"backbone" => "N(-H)-CA(-HA)(-C=O)"}.each do |name, partial_spec|
        spec = spec.gsub "{#{name}}", partial_spec
      end
      parser = SpecificationParser.new(spec)
      parser.parse
      @atom_types = parser.atom_types
      @bonds = parser.bond_types
    end

    def structure # (& : StructureBuilder ->) : Nil
      typer = Typer.new @kind
      with typer yield typer
      @atom_types, @bonds, @link_bond = typer.build
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

  # :nodoc:
  #
  # TODO: replace by a smiles-like parser such that `structure "<spec>"`
  class ResidueType::Typer
    ATOM_NAME_PATTERN  = "[A-Z]{1,3}[0-9]{0,2}"
    ATOM_SEP_REGEX     = /(?<=[A-Z0-9\)\]])#{BOND_ORDER_PATTERN}(?=[A-Z0-9])/
    ATOM_SPEC_REGEX    = /(#{ATOM_NAME_PATTERN})(\[([A-Z][a-z]?)\])?([\+-]\d?)?(\((\d)\))?/
    BOND_ORDER_PATTERN = "[-=#]"
    BOND_REGEX         = /(#{ATOM_NAME_PATTERN})(#{BOND_ORDER_PATTERN})(#{ATOM_NAME_PATTERN})/

    getter atom_types = [] of AtomType
    getter bond_types = [] of BondType
    getter link_bond : BondType?

    protected def initialize(@kind : Residue::Kind)
    end

    private def add_bond(atom_t : AtomType, other : AtomType, order : Int = 1)
      bond = @bond_types.find { |bond| atom_t.in?(bond) && other.in?(bond) }
      if bond && bond.order != order
        raise Error.new("Bond #{bond} already exists")
      elsif bond.nil?
        @bond_types << BondType.new atom_t, other, order
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
      atom_type?(name) || raise Error.new("Unknown atom type #{name}")
    end

    def backbone : Nil
      raise Error.new("Backbone is only valid for protein residues") unless @kind.protein?
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
      check_root "branch", spec
      parse_spec spec
    end

    protected def build : Tuple(Array(AtomType), Array(BondType), BondType?)
      raise Error.new("No atoms for residue type") if @atom_types.empty?
      if @atom_types.size > 1 && @bond_types.empty?
        raise Error.new("No bonds for residue type")
      end

      add_missing_hydrogens
      check_valencies

      {@atom_types, @bond_types, @link_bond}
    end

    private def check_root(cmd : String, desc : String)
      atom_name = extract_root desc
      return if atom_type? atom_name
      parse_exception "#{cmd.capitalize} must start with an existing atom type, " \
                      "got #{atom_name}"
    end

    private def check_valencies
      @atom_types.each do |atom_t|
        num = missing_bonds atom_t
        next if num == 0
        raise Error.new(
          "Atom type #{atom_t} has incorrect valency (#{atom_t.valency - num}), " \
          "expected #{atom_t.valency}")
      end
    end

    def cycle(spec : String)
      # check_root "cycle", spec
      spec += '-' unless /#{BOND_ORDER_PATTERN}$/ =~ spec
      parse_spec "#{spec}#{extract_root spec}"
    end

    private def extract_root(spec : String) : String
      spec[/#{ATOM_NAME_PATTERN}/]
    end

    def link_adjacent_by(spec : String)
      @link_bond = parse_bond spec
    end

    private def missing_bonds(atom_t : AtomType) : Int32
      valency = atom_t.valency
      if bond = @link_bond
        valency -= bond.order if atom_t.in?(bond)
      end
      valency - @bond_types.each.select(&.includes?(atom_t.name)).map(&.order).sum
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
        raise Error.new("Atom #{lhs} cannot be bonded to itself") if lhs == rhs
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
        lhs = atom_types[i]
        rhs = atom_types[i + 1]
        raise Error.new("Atom #{lhs.name} cannot be bonded to itself") if lhs == rhs
        add_bond lhs, rhs, parse_bond_order(bond_char)
      end
    end

    def remove_atom(atom_name : String)
      atom_t = atom_type! atom_name
      @bond_types.reject! &.includes?(atom_t)
      @atom_types.delete atom_t
    end

    def sidechain
      raise Error.new("Sidechain is only valid for protein residues") unless @kind.protein?
      with self yield self
    end

    def sidechain(spec : String)
      sidechain do
        stem spec
      end
    end

    def stem(spec : String)
      spec = "CA-" + spec if @kind.protein?
      parse_spec spec
    end
  end

  private class ResidueType::SpecificationParser
    def initialize(str)
      @reader = Char::Reader.new(str.strip)
      @atom_type_map = {} of String => AtomType
      @bond_type_map = {} of Tuple(String, String) => BondType
    end

    def atom_types : Array(AtomType)
      @atom_type_map.values
    end

    def bond_types : Array(BondType)
      @bond_type_map.values
    end

    private def check_pred(msg : String) : AtomType
      @atom_type_map.last_value? || parse_exception(msg)
    end

    private def consume_element : String
      symbol = String.build do |io|
        io << current_char if current_char.ascii_uppercase?
        if (char = peek_char) && char.ascii_lowercase?
          io << char
          next_char
        end
      end
      parse_exception("Expected element") if symbol.empty?
      symbol
    end

    private def consume_int : Int32
      consume_while(&.ascii_number?).to_i
    end

    private def consume_while(io : IO, & : Char -> Bool) : Nil
      if (yield current_char)
        io << current_char
      end
      while (char = peek_char) && (yield char)
        io << char
        next_char
      end
    end

    private def consume_while(& : Char -> Bool) : String
      String.build do |io|
        consume_while(io) do |char|
          yield char
        end
      end
    end

    private def current_char
      @reader.current_char
    end

    private def each_char(& : Char ->) : Nil
      loop do
        yield current_char
        break unless next_char
      end
    end

    private def next_char : Char?
      if @reader.has_next?
        char = @reader.next_char
        char if char != '\0'
      end
    end

    def parse : Nil
      bond_atom = nil
      bond_order = 1
      root_stack = Deque(AtomType).new
      each_char do |char|
        case char
        when .ascii_letter?
          atom_type = read_atom_type
          @atom_type_map[atom_type.name] ||= atom_type
          if bond_atom
            if bond_atom == atom_type
              parse_exception("Atom #{atom_type.name} cannot be bonded to itself")
            end
            bond_key = {String, String}.from [bond_atom.name, atom_type.name].sort!
            if bond_type = @bond_type_map[bond_key]?
              if bond_type.order != bond_order
                parse_exception("Bond #{bond_type} already exists")
              end
            else
              @bond_type_map[bond_key] = BondType.new(bond_atom, atom_type, bond_order)
            end
            bond_atom = nil
          end
        when '-'
          parse_exception("Unterminated bond") unless peek_char
          bond_atom ||= check_pred("Bond must be preceded by an atom")
          bond_order = 1
        when '='
          parse_exception("Unterminated bond") unless peek_char
          bond_atom ||= check_pred("Bond must be preceded by an atom")
          bond_order = 2
        when '#'
          parse_exception("Unterminated bond") unless peek_char
          bond_atom ||= check_pred("Bond must be preceded by an atom")
          bond_order = 3
        when '('
          if char = peek_char
            parse_exception("Expected bond at the beginning of a branch") unless char.in?("-=#")
          else # end of string
            parse_exception("Unclosed branch")
          end
          root_stack << (bond_atom || check_pred("Branch must be preceded by an atom"))
        when ')'
          bond_atom = root_stack.pop? || parse_exception("Invalid branch termination")
          if char = peek_char
            parse_exception("Expected bond after a branch") unless char.in?("-=#(")
          end
        when .nil?
          break
        else
          parse_exception("Invalid character #{char.inspect}")
        end
      end
      parse_exception("Unclosed branch") unless root_stack.empty?
    end

    # Rename to fail
    private def parse_exception(msg)
      raise ParseException.new(msg)
    end

    private def peek_char : Char?
      if @reader.has_next?
        char = @reader.peek_next_char
        char if char != '\0'
      end
    end

    private def read_atom_type : AtomType
      atom_name = String.build do |io|
        consume_while io, &.ascii_uppercase?
        consume_while io, &.ascii_number?
      end
      parse_exception("Expected atom name") if atom_name.empty?
      atom_type = @atom_type_map[atom_name]?

      next_char

      element = nil
      formal_charge = 0
      valency = nil
      each_char do |char|
        case char
        when '+'
          formal_charge = peek_char.try(&.ascii_number?) ? consume_int : 1
        when '-'
          case peek_char
          when .nil?, '-' # minus charge
            parse_exception("Cannot modify charge of #{atom_name}") if atom_type
            formal_charge = -1
          when .ascii_number? # minus charge as -2, -3, etc.
            parse_exception("Cannot modify charge of #{atom_name}") if atom_type
            formal_charge = consume_int * -1
          when .ascii_letter? # single bond
            @reader.previous_char
            break
          end
        when '['
          parse_exception("Cannot modify element of #{atom_name}") if atom_type
          next_char
          element = consume_element
          case next_char
          when ']' # ok
          when .nil?
            parse_exception("Unclosed bracket")
          when .ascii_uppercase?
            parse_exception("Invalid element")
          else
            parse_exception("Unclosed bracket")
          end
        when '(' # explicit valency
          parse_exception("Cannot modify valency of #{atom_name}") if atom_type
          if peek_char.try(&.ascii_number?) # valency
            next_char
            valency = consume_int
            parse_exception("Unclosed bracket") unless next_char == ')'
          else
            @reader.previous_char
            break
          end
        else
          @reader.previous_char
          break
        end
      end

      atom_type || AtomType.new(atom_name, formal_charge, element, valency)
    end
  end
end
