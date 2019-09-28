module Chem
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
  end

  class Structure::Builder
    private record Conf, id : Char, occupancy : Float64

    private alias NumberType = Number::Primitive
    private alias Coords = Spatial::Vector | Tuple(NumberType, NumberType, NumberType)

    private alias ChainId = Char?
    private alias ResidueId = Tuple(ChainId, String, Int32, Char?)

    @atom_serial : Int32 = 0
    @chain : Chain?
    @chains = {} of ChainId => Chain
    @residue : Residue?
    @residues = {} of ResidueId => Residue
    @structure : Structure

    def initialize(structure : Structure? = nil)
      if structure
        @structure = structure
        structure.each_chain { |chain| @chains[id(of: chain)] = chain }
        @chain = @chains.last_value?
        structure.each_residue { |residue| @residues[id of: residue] = residue }
        @residue = @chain.try &.residues.last
        @atom_serial = structure.each_atom.max_of &.serial
      else
        @structure = Structure.new
      end
    end

    def self.build(structure : Structure? = nil) : Structure
      builder = new structure
      with builder yield builder
      builder.build
    end

    private def [](*, atom name : String) : Atom
      @structure.atoms.reverse_each do |atom|
        return atom if atom.name == name
      end
      raise "Unknown atom #{name.inspect}"
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
      coords = Spatial::Vector.new *coords unless coords.is_a? Spatial::Vector
      Atom.new name, serial, coords, current_residue, **options
    end

    private def add_chain(id : Char) : Chain
      chain = Chain.new id, @structure
      @chains[id(of: chain)] = @chain = chain
    end

    private def add_residue(name : String, number : Int32, ins_code : Char?) : Residue
      residue = Residue.new name, number, ins_code, current_chain
      @residues[id(of: residue)] = @residue = residue
      residue
    end

    def atom(of element : PeriodicTable::Element | String | Symbol,
             at coords : Coords = Spatial::Vector.zero,
             **options) : Atom
      unless element.is_a? PeriodicTable::Element
        element = PeriodicTable[element.to_s.capitalize]
      end
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

    def bond(name : String, other : String, order : Int = 1)
      self[atom: name].bonds.add self[atom: other], order
    end

    def build : Structure
      @structure
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
      @structure.lattice = builder.build
    end

    def lattice(&block) : Lattice
      builder = Lattice::Builder.new
      with builder yield builder
      @structure.lattice = builder.build
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
      @structure.title = title
    end
  end
end
