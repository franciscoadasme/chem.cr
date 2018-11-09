module Chem
  # FIXME: this hack is needed for the require mechanism to work properly
  class System; end

  class Lattice::Builder
    @lattice : Lattice = Lattice[0, 0, 0]

    def self.build : Lattice
      builder = new
      with builder yield builder
      builder.build
    end

    def a(value : Number)
      a Spatial::Vector[value.to_f, 0, 0]
    end

    def a(vector : Spatial::Vector)
      @lattice.a = vector
    end

    def b(value : Number)
      b Spatial::Vector[0, value.to_f, 0]
    end

    def b(vector : Spatial::Vector)
      @lattice.b = vector
    end

    def build : Lattice
      @lattice
    end

    def c(value : Number)
      c Spatial::Vector[0, 0, value.to_f]
    end

    def c(vector : Spatial::Vector)
      @lattice.c = vector
    end

    def scale(by factor : Float64)
      @lattice.scale_factor = factor
    end

    def space_group(group : String)
      @lattice.space_group = group
    end
  end

  class System::Builder
    private record Conf, id : Char, occupancy : Float64

    private alias NumberType = Number::Primitive
    private alias Coords = Spatial::Vector | Tuple(NumberType, NumberType, NumberType)

    private alias ChainId = Char?
    private alias ResidueId = Tuple(ChainId, String, Int32, Char?)

    @atom_serial : Int32 = 0
    @chain : Chain?
    @chains = {} of ChainId => Chain
    @conf : Conf?
    @residue : Residue?
    @residues = {} of ResidueId => Residue
    @system : System

    def initialize(system : System? = nil)
      if system
        @system = system
        system.each_chain { |chain| @chains[id(of: chain)] = chain }
        @chain = @chains.last_value?
        system.each_residue { |residue| @residues[id of: residue] = residue }
        @residue = @chain.try &.residues.last
        @atom_serial = system.each_atom.max_of &.serial
      else
        @system = System.new
      end
    end

    def self.build(system : System? = nil) : System
      builder = new system
      with builder yield builder
      builder.build
    end

    private def []?(*, chain id : ChainId) : Chain?
      @chains[id]?
    end

    private def []?(*, residue id : ResidueId) : Residue?
      @residues[id]?
    end

    private def add_atom(name : String,
                         serial : Int32,
                         coords : Coords,
                         **options) : Atom
      options = options.merge(alt_loc: @conf.try(&.id),
        occupancy: @conf.try(&.occupancy) || 1.0)
      add_atom name, serial, coords, **options
    end

    private def add_atom(name : String,
                         serial : Int32,
                         coords : Coords,
                         alt_loc : Char?,
                         occupancy : Float64,
                         **options) : Atom
      coords = Spatial::Vector.new *coords unless coords.is_a? Spatial::Vector
      atom = Atom.new name, serial, coords, current_residue, alt_loc, **options,
        occupancy: occupancy
      current_residue << atom
      atom
    end

    private def add_chain(id : Char) : Chain
      @system << (chain = Chain.new id, @system)
      @chains[id(of: chain)] = @chain = chain
      chain
    end

    private def add_residue(name : String, number : Int32, ins_code : Char?) : Residue
      current_chain << (residue = Residue.new name, number, ins_code, current_chain)
      @residues[id(of: residue)] = @residue = residue
      @conf = nil
      residue
    end

    def atom(of element : PeriodicTable::Element,
             at coords : Coords = Spatial::Vector.zero,
             **options) : Atom
      ele_count = current_residue.each_atom.count &.element.==(element)
      name = "#{element.symbol}#{ele_count + 1}"
      atom name, coords, **options.merge(element: element)
    end

    def atom(named name : String,
             at coords : Coords = Spatial::Vector.zero,
             **options) : Atom
      add_atom name, (@atom_serial += 1), coords, **options
    end

    def atom(at coords : Coords, **options) : Atom
      atom PeriodicTable::C, coords, **options
    end

    def atoms(*names : String) : Array(Atom)
      names.to_a.map { |name| atom name }
    end

    def build : System
      @system
    end

    def chain : Chain
      @chain = add_chain id: (@chain.try(&.id) || 64.chr).succ
    end

    def chain(named id : Char) : Chain
      return current_chain if id(of: @chain) == id
      @chain = self[chain: id]? || add_chain(id)
    end

    def chain(*args, **options, &block) : Chain
      ch = chain *args, **options
      with self yield self
      ch
    end

    def conf(named id : Char, occupancy : Float64)
      @conf = Conf.new id, occupancy
    end

    def conf(*args, **options, &block)
      conf *args, **options
      with self yield self
      @conf = nil
    end

    private def current_chain : Chain
      @chain || add_chain id: 'A'
    end

    private def current_residue : Residue
      @residue || add_residue(name: "UNK", number: 1, ins_code: nil)
    end

    private def id(of chain : Chain) : ChainId
      chain.id
    end

    private def id(of residue : Residue) : ResidueId
      {id(of: residue.chain), residue.name, residue.number, residue.insertion_code}
    end

    private def id(of object : Nil) : Nil
      nil
    end

    def lattice(a : Number, b : Number, c : Number) : Lattice
      builder = Lattice::Builder.new
      builder.a a
      builder.b b
      builder.c c
      @system.lattice = builder.build
    end

    def lattice(&block) : Lattice
      builder = Lattice::Builder.new
      with builder yield builder
      @system.lattice = builder.build
    end

    def residue : Residue
      residue "UNK"
    end

    def residue(named name : String,
                number : Int32,
                insertion_code : Char? = nil) : Residue
      resid = {current_chain.id, name, number, insertion_code}
      return current_residue if id(of: @residue) == resid
      @residue = self[residue: resid]? || add_residue(name, number, insertion_code)
    end

    def residue(named name : String) : Residue
      next_number = (current_chain.residues[-1]?.try(&.number) || 0) + 1
      residue name, next_number
    end

    def residue(*args, **options, &block) : Residue
      res = residue *args, **options
      with self yield self
      res
    end

    def title(title : String)
      @system.title = title
    end
  end
end
