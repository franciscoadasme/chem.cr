module Chem::Spatial
  struct CoordinatesProxy
    include Enumerable(Vec3)
    include Iterable(Vec3)

    def initialize(@atoms : AtomView, @cell : Parallelepiped? = nil)
    end

    def ==(rhs : Enumerable(Vec3)) : Bool
      zip(rhs) { |a, b| return false if a != b }
      true
    end

    # Superimposes the coordinates onto *other*. Raises `ArgumentError`
    # if the two coordinate sets are of different size.
    #
    # ```
    # conformers = Array(Structure).read "E20_conformers.mol2"
    # ref_pos = conformers[0].coords
    # pos = conformers[1].coords
    # Spatial.rmsd(pos, ref_pos)   # => 7.933736
    # pos.center == ref_pos.center # => false
    # pos.align_to(res_pos)
    # Spatial.rmsd(pos, ref_pos)   # => 3.463298
    # pos.center == ref_pos.center # => true
    # ```
    #
    # The transformation is obtained via the
    # `Transform.aligning(pos, ref_pos)` method, which computes
    # the optimal rotation matrix by minimizing the root mean square
    # deviation (RMSD) using the QCP method (refer to `Spatial.qcp` for
    # details).
    def align_to(other : self) : self
      transform Transform.aligning(self, other)
    end

    def bounds : Parallelepiped
      min = StaticArray[Float64::MAX, Float64::MAX, Float64::MAX]
      max = StaticArray[Float64::MIN, Float64::MIN, Float64::MIN]
      each do |vec|
        3.times do |i|
          min[i] = vec[i] if vec[i] < min.unsafe_fetch(i)
          max[i] = vec[i] if vec[i] > max.unsafe_fetch(i)
        end
      end
      Parallelepiped.new(Vec3[min[0], min[1], min[2]], Vec3[max[0], max[1], max[2]])
    end

    def center : Vec3
      sum / @atoms.size
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
      translate vec / 2 - center.dot(nvec) * nvec
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
      translate vec - center
    end

    # Translates coordinates so that they are centered at the primary unit cell.
    #
    # Raises NotPeriodicError if coordinates are not periodic.
    #
    # ```
    # structure = Structure.read "path/to/file"
    # structure.cell          # => [[1.0 0.0 0.0] [0.0 25.0 0.0] [0.0 0.0 213]]
    # structure.coords.center # => [1.0 2.0 3.0]
    # structure.coords.center_at_cell
    # structure.coords.center # => [0.5 12.5 106.5]
    #
    # structure = Structure.read "path/to/non_periodic_file"
    # structure.coords.center_at_cell # raises NotPeriodicError
    # ```
    def center_at_cell : self
      raise NotPeriodicError.new unless cell = @cell
      center_at cell.center
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
      center_at Vec3.zero
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
      @atoms.each do |atom|
        center += atom.mass * atom.coords
        total_mass += atom.mass
      end
      center / total_mass
    end

    def each(fractional : Bool = false) : Iterator(Vec3)
      if fractional
        raise NotPeriodicError.new unless cell = @cell
        FractionalCoordinatesIterator.new @atoms, cell
      else
        @atoms.each.map &.coords
      end
    end

    def each(fractional : Bool = false, &block : Vec3 ->)
      if fractional
        raise NotPeriodicError.new unless cell = @cell
        @atoms.each { |atom| yield cell.fract(atom.coords) }
      else
        @atoms.each { |atom| yield atom.coords }
      end
    end

    def each_with_atom(fractional : Bool = false, &block : Vec3, Atom ->)
      iter = @atoms.each
      each(fractional) do |vec|
        break unless (atom = iter.next).is_a?(Atom)
        yield vec, atom
      end
    end

    def map!(fractional : Bool = false, &block : Vec3 -> Vec3) : self
      if fractional
        raise NotPeriodicError.new unless cell = @cell
        @atoms.each do |atom|
          atom.coords = cell.cart(yield cell.fract(atom.coords))
        end
      else
        @atoms.each { |atom| atom.coords = yield atom.coords }
      end
      self
    end

    def map_with_atom!(fractional : Bool = false, &block : Vec3, Atom -> Vec3) : self
      iter = @atoms.each
      map!(fractional) do |vec|
        break unless (atom = iter.next).is_a?(Atom)
        yield vec, atom
      end
      self
    end

    # Returns the weighted root mean square deviation (RMSD) in Å
    # between the coordinates and *other*.
    #
    # The RMSD is defined as the weighted average Euclidean distance
    # between the two coordinates sets *A* and *B*. The *weights* (e.g.,
    # atom masses) determine the relative weights of each coordinate
    # when calculating the RMSD.
    #
    # If the minimum RMSD is desired (*minimize* is `true`), the RMSD
    # will be computed using the quaternion-based characteristic
    # polynomial (QCP) method (refer to `.qcp`). This method superimpose
    # the coordinates onto *other* by computing the optimal rotation
    # between the two coordinate sets before calculating the RMSD.
    def rmsd(
      other : self,
      weights : Indexable(Float64),
      minimize : Bool = false
    ) : Float64
      pos = to_a           # FIXME: avoid copying coordinates
      ref_pos = other.to_a # FIXME: avoid copying coordinates
      raise ArgumentError.new("Incompatible coordinates") if pos.size != ref_pos.size

      if minimize
        # requires that the coordinates are centered at origin
        # FIXME: replace by pos.dup.center_at_origin(weights)
        center = pos.average(weights)
        pos.map! &.-(center)
        center = ref_pos.average(weights)
        ref_pos.map! &.-(center)

        # weights should be relative to the mean
        weight_mean = weights.mean
        weights.map! &./(weight_mean)

        _, rmsd = Spatial.qcp(pos, ref_pos, weights)
        rmsd
      else
        Math.sqrt((0...pos.size).average(weights) do |i|
          pos.unsafe_fetch(i).distance2 ref_pos.unsafe_fetch(i)
        end)
      end
    end

    # Returns the root mean square deviation (RMSD) in Å between the
    # coordinates and *other*.
    #
    # The RMSD is defined as the average Euclidean distance between the
    # two coordinates sets *A* and *B*.
    #
    # If the minimum RMSD is desired (*minimize* is `true`), the RMSD
    # will be computed using the quaternion-based characteristic
    # polynomial (QCP) method (refer to `.qcp`). This method superimpose
    # the coordinates onto *other* by computing the optimal rotation
    # between the two coordinate sets before calculating the RMSD.
    def rmsd(
      other : CoordinatesProxy,
      minimize : Bool = false
    ) : Float64
      pos = to_a           # FIXME: avoid copying coordinates
      ref_pos = other.to_a # FIXME: avoid copying coordinates

      if minimize
        # requires that the coordinates are centered at origin
        # FIXME: replace by pos.dup.center_at_origin
        center = pos.mean
        pos.map! &.-(center)
        center = ref_pos.mean
        ref_pos.map! &.-(center)
        _, rmsd = Spatial.qcp pos, ref_pos
        rmsd
      else
        Math.sqrt((0...pos.size).mean do |i|
          pos.unsafe_fetch(i).distance2 ref_pos.unsafe_fetch(i)
        end)
      end
    end

    # Returns the radius of gyration in Å.
    #
    # The radius of gyration is a measure of the distribution of the
    # atoms around the center of mass of a molecule. The radius of
    # gyration is defined as the root-mean-square distance of the
    # atoms from the axis of rotation:
    #
    # RDGYR =  √ 1 / N * Σ(r - c)²
    #
    # where *N* is the number of atoms in the molecule, *r* is the
    # coordinates of each atom, and *c* is the center of mass of the
    # molecule.
    def rdgyr : Float64
      center = self.com
      Math.sqrt mean(&.distance2(center))
    end

    # Rotates the coordinates by the given Euler angles in degrees. The
    # rotation will be centered at *pivot*, which defaults to the
    # coordinates' center.
    #
    # Delegates to `Quat.rotation` for computing the rotation.
    def rotate(x : Number, y : Number, z : Number, pivot : Vec3 = center) : self
      rotate Quat.rotation(x, y, z), pivot
    end

    # Rotates the coordinates about *rotaxis* by *angle* degrees. The
    # rotation will be centered at *pivot*, which defaults to the
    # coordinates' center.
    #
    # Delegates to `Quat.rotation` for computing the rotation.
    def rotate(about rotaxis : Vec3, by angle : Number, pivot : Vec3 = center) : self
      rotate Quat.rotation(rotaxis, angle), pivot
    end

    # Rotates the coordinates by the given quaternion. The
    # rotation will be centered at *pivot*, which defaults to the
    # coordinates' center.
    def rotate(quat : Quat, pivot : Vec3 = center) : self
      if pivot.zero?
        map! &.rotate(quat)
      else
        offset = pivot - Vec3[0, 0, 0]
        transform = Transform.translation(-offset).rotate(quat).translate(offset)
        map! &.transform(transform)
      end
    end

    # Transforms the coordinates by the given transformation.
    def transform(transform : Transform) : self
      map! &.transform(transform)
    end

    # Translates the coordinates by the given offset.
    def translate(by offset : Vec3) : self
      map! &.translate(offset)
    end

    def to_a(fractional : Bool = false) : Array(Vec3)
      ary = [] of Vec3
      each(fractional) { |coords| ary << coords }
      ary
    end

    def to_cart! : self
      raise NotPeriodicError.new unless cell = @cell
      map! { |vec| cell.cart(vec) }
    end

    def to_fract! : self
      raise NotPeriodicError.new unless cell = @cell
      map! { |vec| cell.fract(vec) }
    end

    def unwrap : self
      raise Spatial::NotPeriodicError.new unless cell = @cell
      to_fract!
      moved_atoms = Set(Atom).new
      @atoms.each_fragment do |fragment|
        assemble_fragment(fragment[0], fragment[0].coords, moved_atoms)
        fragment.coords.translate(-fragment.coords.center.map(&.floor))
        moved_atoms.clear
      end
      to_cart!
      self
    end

    private def assemble_fragment(atom, center, moved_atoms)
      return if atom.in?(moved_atoms)

      atom.coords -= (atom.coords - center).map(&.round)
      moved_atoms << atom

      atom.each_bonded_atom do |other|
        assemble_fragment other, atom.coords, moved_atoms
      end
    end

    def wrap(around center : Vec3? = nil) : self
      raise NotPeriodicError.new unless cell = @cell
      wrap cell, center
    end

    def wrap(cell : Parallelepiped, around center : Vec3? = nil) : self
      center ||= cell.center

      # TODO: move this conditional to `Parallelepiped.wrap`
      if cell.orthogonal?
        vecs = cell.basisvec
        normed_vecs = vecs.map &.normalize
        map! do |vec|
          d = vec - center
          3.times do |i|
            fd = d.dot(normed_vecs[i]) / vecs[i].abs
            vec -= fd.round * vecs[i] if fd.abs > 0.5
          end
          vec
        end
      else
        offset = cell.fract(center) - Vec3[0.5, 0.5, 0.5]
        # FIXME: map!(fractional: true) does not work with external cell
        map!(fractional: true) { |vec| vec - (vec - offset).map(&.floor) }
      end

      self
    end

    private class FractionalCoordinatesIterator
      include Iterator(Vec3)
      include IteratorWrapper

      @iterator : Iterator(Atom)

      def initialize(atoms : AtomView, @cell : Parallelepiped)
        @iterator = atoms.each
      end

      def next : Vec3 | Iterator::Stop
        atom = wrapped_next
        @cell.fract atom.coords
      end
    end
  end
end
