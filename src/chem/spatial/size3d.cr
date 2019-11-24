module Chem::Spatial
  struct Size3D
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
  end
end
