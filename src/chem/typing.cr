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
      @element.max_valency + @formal_charge
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

    def includes?(name : String) : Bool
      any? &.name.==(name)
    end

    def inspect(io : IO) : Nil
      io << "<BondType " << self[0].name << to_char << self[1].name << '>'
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

    def to_char : Char
      case @order
      when 1 then '-'
      when 2 then '='
      when 3 then '#'
      else        raise "BUG: unreachable"
      end
    end
  end

  class ResidueType
    private REGISTRY = {} of String => ResidueType

    @atom_types : Array(AtomType)
    @bonds : Array(BondType)

    getter name : String
    getter kind : Residue::Kind
    getter link_bond : BondType?
    getter description : String
    getter root : AtomType?
    getter code : Char?
    getter symmetric_atom_groups : Array(Array(Tuple(String, String)))?

    def initialize(
      @description : String,
      @name : String,
      @code : Char?,
      @kind : Residue::Kind,
      atom_types : Array(AtomType),
      bonds : Array(BondType),
      @link_bond : BondType? = nil,
      @root : AtomType? = nil,
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
        builder.names.each do |name|
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
    @root : AtomType?
    @symmetric_atom_groups = [] of Array(Tuple(String, String))

    def build : ResidueType
      raise Error.new("Missing residue description") unless (description = @description)
      raise Error.new("Missing residue name") if @names.empty?

      root "CA" if !@root && @kind.protein?

      ResidueType.new description, @names.first, @code, @kind, @atom_types, @bonds,
        @link_bond, @root, @symmetric_atom_groups
    end

    def code(char : Char) : Nil
      @code = char
    end

    def description(name : String)
      @description = name
    end

    def kind(kind : Residue::Kind)
      @kind = kind
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

    def root(atom_name : String)
      @root = check_atom_type atom_name
    end

    def structure(spec : String) : Nil
      structure do
        stem spec
      end
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

    private def check_atom_type(name : String) : AtomType
      if atom_type = @atom_types.find(&.name.==(name))
        atom_type
      else
        raise Error.new("Unknown atom type #{name}")
      end
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
        raise Error.new("Bond #{atom_t.name}#{bond.to_char}#{other.name} already exists")
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
end
