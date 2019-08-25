module Chem::Spatial
  struct CoordinatesProxy
    include Enumerable(Vector)

    def initialize(@atoms : AtomCollection, @lattice : Lattice? = nil)
    end

    def bounds : Bounds
      min = StaticArray[Float64::MAX, Float64::MAX, Float64::MAX]
      max = StaticArray[Float64::MIN, Float64::MIN, Float64::MIN]
      each do |coords|
        3.times do |i|
          min[i] = coords[i] if coords[i] < min.unsafe_fetch(i)
          max[i] = coords[i] if coords[i] > max.unsafe_fetch(i)
        end
      end
      origin = Vector.new min[0], min[1], min[2]
      size = Size3D.new max[0] - min[0], max[1] - min[1], max[2] - min[2]
      Bounds.new origin, size
    end

    def center : Vector
      sum / @atoms.n_atoms
    end

    def each(fractional : Bool = false, &block : Vector ->)
      if fractional
        raise NotPeriodicError.new unless lattice = @lattice
        transform = AffineTransform.cart_to_fractional lattice
        @atoms.each_atom { |atom| yield transform * atom.coords }
      else
        @atoms.each_atom { |atom| yield atom.coords }
      end
    end

    def each_with_atom(fractional : Bool = false, &block : Vector, Atom ->)
      iter = @atoms.each_atom
      each(fractional) do |vec|
        break unless (atom = iter.next).is_a?(Atom)
        yield vec, atom
      end
    end

    def map(fractional : Bool = false, &block : Vector -> Vector) : Array(Vector)
      ary = [] of Vector
      each(fractional) { |coords| ary << yield coords }
      ary
    end

    def map!(fractional : Bool = false, &block : Vector -> Vector) : self
      if fractional
        raise NotPeriodicError.new unless lattice = @lattice
        transform = AffineTransform.cart_to_fractional lattice

        @atoms.each_atom do |atom|
          new_coords = yield transform * atom.coords
          atom.coords = transform.inv * new_coords
        end
      else
        @atoms.each_atom { |atom| atom.coords = yield atom.coords }
      end
      self
    end

    def map_with_atom(fractional : Bool = false,
                      &block : Vector, Atom -> Vector) : Array(Vector)
      ary = [] of Vector
      each_with_atom(fractional) do |coords, atom|
        ary << yield coords, atom
      end
      ary
    end

    def map_with_atom!(fractional : Bool = false, &block : Vector, Atom -> Vector) : self
      iter = @atoms.each_atom
      map!(fractional) do |vec|
        break unless (atom = iter.next).is_a?(Atom)
        yield vec, atom
      end
      self
    end

    def transform(transform : AffineTransform) : Array(Vector)
      map &.*(transform)
    end

    def transform!(transform : AffineTransform) : self
      map! &.*(transform)
    end

    def translate(by offset : Vector) : Array(Vector)
      map &.+(offset)
    end

    def translate!(by offset : Vector) : self
      map! &.+(offset)
    end

    def to_a(fractional : Bool = false) : Array(Vector)
      ary = [] of Vector
      each(fractional) { |coords| ary << coords }
      ary
    end

    def to_cartesian! : self
      raise NotPeriodicError.new unless lattice = @lattice
      transform! AffineTransform.fractional_to_cart(lattice)
    end

    def to_fractional! : self
      raise NotPeriodicError.new unless lattice = @lattice
      transform! AffineTransform.cart_to_fractional(lattice)
    end
  end
end
