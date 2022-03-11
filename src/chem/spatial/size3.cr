module Chem::Spatial
  # A `Size3` represents the size of an object in three-dimensional
  # space.
  struct Size3
    # X component of the size.
    getter x : Float64
    # Y component of the size.
    getter y : Float64
    # Z component of the size.
    getter z : Float64

    # Creates a size with values *x*, *y* and *z*. Raises
    # `ArgumentError` if *x*, *y* or *z* is negative.
    def initialize(@x : Float64, @y : Float64, @z : Float64)
      raise ArgumentError.new("Negative size") if x < 0 || y < 0 || z < 0
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

    # Returns the element-wise substraction of the size by *rhs*.
    #
    # WARNING: This will clamp negative values to zero.
    def -(rhs : self) : self
      self.class.new(
        Math.max(0.0, @x - rhs.x),
        Math.max(0.0, @y - rhs.y),
        Math.max(0.0, @z - rhs.z),
      )
    end

    {% begin %}
      {% op_name_map = {"+" => "addition",
                        "-" => "substraction",
                        "*" => "multiplication",
                        "/" => "division"} %}
      {% for op in %w(* /) %}
        # Returns the element-wise {{op_name_map[op].id}} of the size by
        # *rhs*.
        def {{op.id}}(rhs : Number) : self
          self.class[@x {{op.id}} rhs, @y {{op.id}} rhs, @z {{op.id}} rhs]
        end
      {% end %}

      {% for op in %w(+ * /) %}
        # Returns the element-wise {{op_name_map[op].id}} of the size by
        # *rhs*.
        def {{op.id}}(rhs : self) : self
          self.class.new(@x {{op.id}} rhs.x, @y {{op.id}} rhs.y, @z {{op.id}} rhs.z)
        end
      {% end %}
    {% end %}

    # Returns the element at *index* in the XYZ order. Raises
    # `IndexError` if *index* is out of bounds.
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
      case index
      when 0 then @x
      when 1 then @y
      when 2 then @z
      else        raise IndexError.new
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
      @x.close_to?(rhs.x, delta) &&
        @y.close_to?(rhs.y, delta) &&
        @z.close_to?(rhs.z, delta)
    end
  end
end
