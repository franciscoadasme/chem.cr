module Chem::Spatial
  # A `Size3` represents the size of an object in three-dimensional
  # space.
  struct Size3
    @buffer : FloatTriple

    # Creates a size with values *x*, *y* and *z*. Raises
    # `ArgumentError` if *x*, *y* or *z* is negative.
    def initialize(x : Float64, y : Float64, z : Float64)
      raise ArgumentError.new "Negative size" if x < 0 || y < 0 || z < 0
      @buffer = {x, y, z}
    end

    # Returns a size with values *x*, *y* and *z*.
    @[AlwaysInline]
    def self.[](x : Number, y : Number, z : Number) : self
      new x.to_f, y.to_f, z.to_f
    end

    # Returns the zero size.
    def self.zero : self
      Size3[0, 0, 0]
    end

    {% begin %}
      {% op_map = {"*" => "multiplication", "/" => "division"} %}
      {% for op in %w(* /) %}
        # Returns the element-wise {{op_map[op].id}} of the vector by
        # *rhs*.
        def {{op.id}}(rhs : Number) : self
          Size3[*@buffer.map(&.{{op.id}}(rhs))]
        end
      {% end %}
    {% end %}

    # Returns the element at *index*. Raises `IndexError` if *index* is
    # out of bounds.
    #
    # ```
    # size = Size3[10, 15, 20]
    # size[0]  # => 10
    # size[1]  # => 15
    # size[2]  # => 20
    # size[3]  # raises IndexError
    # size[-1] # raises IndexError
    # ```
    def [](index : Int) : Float64
      if 0 <= index < 3
        @buffer[index]
      else
        raise IndexError.new
      end
    end

    # Returns `true` if the elements of the size are within *delta*
    # from each other, else `false`.
    #
    # ```
    # Size3[1, 2, 3].close_to?(Size3[1, 2, 3])                     # => true
    # Size3[1, 2, 3].close_to?(Size3[1.001, 1.999, 3.00004], 1e-3) # => true
    # Size3[1, 2, 3].close_to?(Size3[3, 2, 1])                     # => false
    # Size3[1, 2, 3].close_to?(Size3[1.001, 1.999, 3.00004], 1e-8) # => false
    # ```
    def close_to?(rhs : self, delta : Number = Float64::EPSILON) : Bool
      # TODO: add Indexable.close_to? and use that instead
      (0..2).all? do |i|
        @buffer[i].close_to?(rhs[i], delta)
      end
    end
  end
end
