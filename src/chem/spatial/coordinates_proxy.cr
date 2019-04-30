module Chem::Spatial
  struct CoordinatesProxy
    include Enumerable(Vector)

    def initialize(@atoms : AtomCollection, @lattice : Lattice? = nil)
    end

    def each(fractional : Bool = false, &block : Vector ->)
      if fractional
        if lattice = @lattice
          transform = AffineTransform.cart_to_fractional lattice
          @atoms.each_atom { |atom| yield transform * atom.coords }
        else
          non_periodic_exception
        end
      else
        @atoms.each_atom { |atom| yield atom.coords }
      end
    end

    def map(fractional : Bool = false, &block : Vector -> Vector) : Array(Vector)
      ary = [] of Vector
      each(fractional) { |coords| ary << yield coords }
      ary
    end

    def map!(fractional : Bool = false, &block : Vector -> Vector) : self
      if fractional
        if lattice = @lattice
          transform = AffineTransform.cart_to_fractional lattice

          @atoms.each_atom do |atom|
            new_coords = yield transform * atom.coords
            atom.coords = transform.inv * new_coords
          end
        else
          non_periodic_exception
        end
      else
        @atoms.each_atom { |atom| atom.coords = yield atom.coords }
      end
      self
    end

    private def non_periodic_exception
      raise Error.new "Cannot compute fractional coordinates for non-periodic atoms"
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
      if lattice = @lattice
        transform! AffineTransform.fractional_to_cart(lattice)
      else
        non_periodic_exception
      end
    end

    def to_fractional! : self
      if lattice = @lattice
        transform! AffineTransform.cart_to_fractional(lattice)
      else
        non_periodic_exception
      end
    end
  end
end
