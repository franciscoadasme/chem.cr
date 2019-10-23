require "../templates/all"

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
    @atom_serial : Int32 = 0
    @chain : Chain?
    @residue : Residue?
    @structure : Structure

    def initialize(structure : Structure? = nil)
      if structure
        @structure = structure
        @chain = structure.each_chain.last
        @residue = structure.each_residue.last
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

    def atom(coords : Spatial::Vector, **options) : Atom
      atom :C, coords, **options
    end

    def atom(element : PeriodicTable::Element | Symbol, coords : Spatial::Vector, **options) : Atom
      element = PeriodicTable[element.to_s.capitalize] if element.is_a?(Symbol)
      id = residue.each_atom.count(&.element.==(element)) + 1
      atom "#{element.symbol}#{id}", coords, **options.merge(element: element)
    end

    def atom(name : String, coords : Spatial::Vector, **options) : Atom
      Atom.new name, (@atom_serial += 1), coords, residue, **options
    end

    def bond(name : String, other : String, order : Int = 1)
      atom!(name).bonds.add atom!(other), order
    end

    def build : Structure
      @structure
    end

    def chain : Chain
      @chain ||= next_chain
    end

    def chain(& : self ->) : Nil
      @chain = next_chain
      with self yield self
    end

    def chain(id : Char) : Chain
      @chain = @structure[id]? || Chain.new(id, @structure)
    end

    def chain(id : Char, & : self ->) : Nil
      chain id
      with self yield self
    end

    def lattice(a : Spatial::Vector, b : Spatial::Vector, c : Spatial::Vector) : Lattice
      @structure.lattice = Lattice.new a, b, c
    end

    def lattice(a : Number, b : Number, c : Number) : Lattice
      @structure.lattice = Lattice.orthorombic a.to_f, b.to_f, c.to_f
    end

    def residue : Residue
      @residue || next_residue
    end

    def residue(name : String) : Residue
      @residue = next_residue name
    end

    def residue(name : String, & : self ->) : Nil
      residue name
      with self yield self
    end

    def residue(name : String, number : Int32, inscode : Char? = nil) : Residue
      @residue = chain[number, inscode]? || begin
        residue = Residue.new(name, number, inscode, chain)
        if res_t = Topology::Templates[name]?
          residue.kind = Residue::Kind.from_value res_t.kind.to_i
        end
        residue
      end
    end

    def residue(name : String, number : Int32, inscode : Char? = nil, & : self ->) : Nil
      residue name, number, inscode
      with self yield self
    end

    def title(title : String)
      @structure.title = title
    end

    private def atom!(name : String) : Atom
      if residue = @residue
        residue.each_atom do |atom|
          return atom if atom.name == name
        end
      end
      raise "Unknown atom #{name.inspect}"
    end

    private def next_chain : Chain
      chain (@chain.try(&.id) || 64.chr).succ
    end

    private def next_residue(name : String = "UNK") : Residue
      residue name, (chain.each_residue.max_of?(&.number) || 0) + 1
    end
  end
end
