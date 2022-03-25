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

    protected def build : ResidueType
      # TODO: make description optional
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

    def name(*names : String)
      @names.concat names
    end

    def root(atom_name : String)
      @root_atom = check_atom_type atom_name
    end

    def structure(spec : String, aliases : Hash(String, String)? = nil) : Nil
      parser = SpecificationParser.new(spec, aliases)
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

  private class ResidueType::SpecificationParser
    ALIASES = {"backbone" => "N(-H)-CA(-HA)(-C=O)"}

    def initialize(str, aliases : Hash(String, String)? = nil)
      @reader = Char::Reader.new(str.strip)
      @atom_type_map = {} of String => AtomType
      @bond_type_map = {} of Tuple(String, String) => BondType
      @aliases = {} of String => String
      @aliases.merge! ALIASES
      @aliases.merge! aliases if aliases
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
      advance_char = true
      loop do
        case char = @reader.current_char
        when .ascii_letter?
          atom_type = read_atom_type
          # TODO: Remove this hack: use * to denote cycles
          # TODO: check for duplicates in read_atom_type
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
        when '{' # alias like "{backbone}"
          name = consume_while &.ascii_lowercase?
          parse_exception("Expected alias") if name.empty?
          spec = @aliases[name]? || parse_exception("Unknown alias #{name}")
          parse_exception("Unclosed alias") unless next_char == '}'
          raw_value = String.build do |io|
            io << @reader.string[0, @reader.pos - name.size - 1] \
              << spec \
              << @reader.string[(@reader.pos + 1)..]
          end
          @reader = Char::Reader.new(raw_value, @reader.pos - name.size - 1)
          advance_char = false # reader already consumes first char on creation
        when .nil?
          break
        else
          parse_exception("Invalid character #{char.inspect}")
        end

        if advance_char
          break unless next_char
        else
          advance_char = true
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
      loop do
        case char = @reader.current_char
        when '+'
          formal_charge = peek_char.try(&.ascii_number?) ? consume_int : 1
        when '-'
          case peek_char
          when .nil?, '-' # minus charge (end of str or --, which is equal to -1-)
            parse_exception("Cannot modify charge of #{atom_name}") if atom_type
            formal_charge = -1
          when .ascii_number? # minus charge as -2, -3, etc.
            parse_exception("Cannot modify charge of #{atom_name}") if atom_type
            formal_charge = consume_int * -1
          else # single bond
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
        break unless next_char
      end

      atom_type || AtomType.new(atom_name, formal_charge, element, valency)
    end
  end
end
