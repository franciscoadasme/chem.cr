module Chem::Spatial
  struct Quaternion
    getter v : Vec3
    getter w : Float64

    def initialize(@w : Float64, @v : Vec3)
    end

    def self.[](w : Float64, x : Float64, y : Float64, z : Float64) : self
      Quaternion.new w, Vec3[x, y, z]
    end

    def self.aligning(v1 : Vec3, to v2 : Vec3) : self
      Quaternion.rotation v1.cross(v2), Spatial.angle(v1, v2)
    end

    def self.identity : self
      new 1, Vec3.zero
    end

    def self.rotation(about rotaxis : Vec3, by theta : Float64) : self
      theta = theta.radians / 2
      Quaternion.new Math.cos(theta), Math.sin(theta) * rotaxis.normalize
    end

    def self.zero : self
      new 0, Vec3.zero
    end

    def +(other : self) : self
      Quaternion.new @w + other.w, @v + other.v
    end

    def - : self
      Quaternion.new -@w, -@v
    end

    def -(other : self) : self
      Quaternion.new @w - other.w, @v - other.v
    end

    def *(other : self) : self
      w = @w * other.w - @v.dot(other.v)
      v = @w * other.v + other.w * @v + @v.cross(other.v)
      Quaternion.new w, v
    end

    def *(other : Vec3) : self
      w = -@v.dot(other)
      v = @w * other + @v.cross(other)
      Quaternion.new w, v
    end

    def *(other : Number) : self
      Quaternion.new @w * other, @v * other
    end

    def /(other : Number) : self
      Quaternion.new @w / other, @v / other
    end

    def [](index : Int) : Float64
      case index
      when 0 then @w
      when 1 then @v.x
      when 2 then @v.y
      when 3 then @v.z
      else
        raise IndexError.new
      end
    end

    def conj : self
      Quaternion.new @w, -@v
    end

    def dot(other : self) : Float64
      @w * other.w + @v.dot(other.v)
    end

    def inv : self
      conj / (@w**2 + @v.x**2 + @v.y**2 + @v.z**2)
    end

    def norm : Float64
      Math.sqrt @w**2 + @v.x**2 + @v.y**2 + @v.z**2
    end

    def normalize : self
      return dup if zero?
      self / norm
    end

    def rotate(vec : Vec3) : Vec3
      # (self * vec * inverse).v
      t = 2 * @v.cross(vec)
      vec + @w * t + @v.cross(t)
    end

    def unit? : Bool
      (norm - 1).abs <= 1e-15
    end

    def zero? : Bool
      @w == 0 && @v.zero?
    end
  end
end
