module Chem::Spatial
  struct Size
    getter x : Float64
    getter y : Float64
    getter z : Float64

    def initialize(@x : Float64, @y : Float64, @z : Float64)
      raise ArgumentError.new "Negative size" if @x < 0 || @y < 0 || @z < 0
    end

    def self.[](x : Float64, y : Float64, z : Float64) : self
      new x, y, z
    end

    def self.zero : self
      new 0, 0, 0
    end

    {% for op in %w(* /) %}
      def {{op.id}}(rhs : Number) : self
        Size.new @x {{op.id}} rhs, @y {{op.id}} rhs, @z {{op.id}} rhs
      end
    {% end %}

    # Returns the element at *index*. Raises `IndexError` if *index* is
    # out of bounds.
    #
    # ```
    # ary = Size[10, 15, 20]
    # ary[0]  # => 10
    # ary[1]  # => 15
    # ary[2]  # => 20
    # ary[3]  # raises IndexError
    # ary[-1] # raises IndexError
    # ```
    def [](index : Int) : Float64
      self[index]? || raise IndexError.new
    end

    # Returns the element at *index*. Returns `nil` if *index* is out of
    # bounds.
    #
    # ```
    # ary = Size[10, 15, 20]
    # ary[0]?  # => 10
    # ary[1]?  # => 15
    # ary[2]?  # => 20
    # ary[3]?  # => nil
    # ary[-1]? # => nil
    # ```
    def []?(index : Int) : Float64?
      case index
      when 0 then @x
      when 1 then @y
      when 2 then @z
      end
    end

    def volume : Float64
      @x * @y * @z
    end
  end
end
