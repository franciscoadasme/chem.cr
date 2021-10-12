module Chem::Spatial
  struct CoordinatesProxy
    include Enumerable(Vec3)
    include Iterable(Vec3)

    def initialize(@atoms : AtomCollection, @lattice : Lattice? = nil)
    end

    def ==(rhs : Enumerable(Vec3)) : Bool
      zip(rhs) { |a, b| return false if a != b }
      true
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
      origin = Vec3.new min[0], min[1], min[2]
      size = Size.new max[0] - min[0], max[1] - min[1], max[2] - min[2]
      Bounds.new origin, size
    end

    def center : Vec3
      sum / @atoms.n_atoms
    end

    # Translates coordinates so that the center is at the middle of *vec*.
    #
    # ```
    # structure = Structure.read "path/to/file"
    # structure.coords.center # => [1.5 2.0 3.2]
    # structure.coords.center_along Vec3[0, 10, 0]
    # structure.coords.center # => [1.5 5.0 3.2]
    # ```
    def center_along(vec : Vec3) : self
      nvec = vec.normalize
      translate! vec / 2 - center.dot(nvec) * nvec
    end

    # Translates coordinates so that the center is at *vec*.
    #
    # ```
    # structure = Structure.read "path/to/file"
    # structure.coords.center # => [1.0 2.0 3.0]
    # structure.coords.center_at Vec3[10, 20, 30]
    # structure.coords.center # => [10 20 30]
    # ```
    def center_at(vec : Vec3) : self
      translate! vec - center
    end

    # Translates coordinates so that they are centered at the primary unit cell.
    #
    # Raises NotPeriodicError if coordinates are not periodic.
    #
    # ```
    # structure = Structure.read "path/to/file"
    # structure.lattice       # => [[1.0 0.0 0.0] [0.0 25.0 0.0] [0.0 0.0 213]]
    # structure.coords.center # => [1.0 2.0 3.0]
    # structure.coords.center_at_cell
    # structure.coords.center # => [0.5 12.5 106.5]
    #
    # structure = Structure.read "path/to/non_periodic_file"
    # structure.coords.center_at_cell # raises NotPeriodicError
    # ```
    def center_at_cell : self
      raise NotPeriodicError.new unless lattice = @lattice
      center_at lattice.bounds.center
    end

    # Translates coordinates so that the center is at the origin.
    #
    # ```
    # structure = Structure.read "path/to/file"
    # structure.coords.center # => [1.0 2.0 3.0]
    # structure.coords.center_at_origin
    # structure.coords.center # => [0.0 0.0 0.0]
    # ```
    def center_at_origin : self
      center_at Vec3.origin
    end

    # Returns the center of mass.
    #
    # ```
    # structure = Chem::Structure.build do
    #   atom :O, Vec3[1, 2, 3]
    #   atom :H, Vec3[4, 5, 6]
    #   atom :H, Vec3[7, 8, 9]
    # end
    # structure.coords.center # => [4.0 5.0 6.0]
    # structure.coords.com    # => [1.5035248 2.5035248 3.5035248]
    # ```
    def com : Vec3
      center = Vec3[0, 0, 0]
      total_mass = 0.0
      each_with_atom do |vec, atom|
        center += atom.mass * vec
        total_mass += atom.mass
      end
      center / total_mass
    end

    def each(fractional : Bool = false) : Iterator(Vec3)
      if fractional
        raise NotPeriodicError.new unless lattice = @lattice
        FractionalCoordinatesIterator.new @atoms, lattice
      else
        @atoms.each_atom.map &.coords
      end
    end

    def each(fractional : Bool = false, &block : Vec3 ->)
      if fractional
        raise NotPeriodicError.new unless lattice = @lattice
        @atoms.each_atom { |atom| yield atom.coords.to_fractional lattice }
      else
        @atoms.each_atom { |atom| yield atom.coords }
      end
    end

    def each_with_atom(fractional : Bool = false, &block : Vec3, Atom ->)
      iter = @atoms.each_atom
      each(fractional) do |vec|
        break unless (atom = iter.next).is_a?(Atom)
        yield vec, atom
      end
    end

    def map(fractional : Bool = false, &block : Vec3 -> Vec3) : Array(Vec3)
      ary = [] of Vec3
      each(fractional) { |coords| ary << yield coords }
      ary
    end

    def map!(fractional : Bool = false, &block : Vec3 -> Vec3) : self
      if fractional
        raise NotPeriodicError.new unless lattice = @lattice
        @atoms.each_atom do |atom|
          atom.coords = (yield atom.coords.to_fractional(lattice)).to_cartesian lattice
        end
      else
        @atoms.each_atom { |atom| atom.coords = yield atom.coords }
      end
      self
    end

    def map_with_atom(fractional : Bool = false,
                      &block : Vec3, Atom -> Vec3) : Array(Vec3)
      ary = [] of Vec3
      each_with_atom(fractional) do |coords, atom|
        ary << yield coords, atom
      end
      ary
    end

    def map_with_atom!(fractional : Bool = false, &block : Vec3, Atom -> Vec3) : self
      iter = @atoms.each_atom
      map!(fractional) do |vec|
        break unless (atom = iter.next).is_a?(Atom)
        yield vec, atom
      end
      self
    end

    def transform(transform : AffineTransform) : Array(Vec3)
      map &.*(transform)
    end

    def transform!(transform : AffineTransform) : self
      map! &.*(transform)
    end

    def translate(by offset : Vec3) : Array(Vec3)
      map &.+(offset)
    end

    def translate!(by offset : Vec3) : self
      map! &.+(offset)
    end

    def to_a(fractional : Bool = false) : Array(Vec3)
      ary = [] of Vec3
      each(fractional) { |coords| ary << coords }
      ary
    end

    def to_cartesian! : self
      raise NotPeriodicError.new unless lattice = @lattice
      map! &.to_cartesian(lattice)
    end

    def to_fractional! : self
      raise NotPeriodicError.new unless lattice = @lattice
      map! &.to_fractional(lattice)
    end

    def wrap(around center : Vec3? = nil) : self
      raise NotPeriodicError.new unless lattice = @lattice
      wrap lattice, center
    end

    def wrap(lattice : Lattice, around center : Vec3? = nil) : self
      center ||= lattice.bounds.center

      if lattice.cuboid?
        vecs = {lattice.i, lattice.j, lattice.k}
        normed_vecs = vecs.map &.normalize
        map! do |vec|
          d = vec - center
          3.times do |i|
            fd = d.dot(normed_vecs[i]) / vecs[i].size
            vec -= fd.round * vecs[i] if fd.abs > 0.5
          end
          vec
        end
      else
        offset = center.to_fractional(lattice) - Vec3[0.5, 0.5, 0.5]
        map!(fractional: true) { |vec| vec - (vec - offset).floor }
      end

      self
    end

    private class FractionalCoordinatesIterator
      include Iterator(Vec3)
      include IteratorWrapper

      @iterator : Iterator(Atom)

      def initialize(atoms : AtomCollection, @lattice : Lattice)
        @iterator = atoms.each_atom
      end

      def next : Vec3 | Iterator::Stop
        atom = wrapped_next
        atom.coords.to_fractional @lattice
      end
    end
  end
end
