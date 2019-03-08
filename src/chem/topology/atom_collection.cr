module Chem
  module AtomCollection
    abstract def each_atom : Iterator(Atom)

    def atoms : AtomView
      AtomView.new each_atom.to_a
    end

    def bounds : Spatial::Bounds
      min = StaticArray[Float64::MAX, Float64::MAX, Float64::MAX]
      max = StaticArray[Float64::MIN, Float64::MIN, Float64::MIN]
      each_atom do |atom|
        3.times do |i|
          min[i] = atom.coords[i] if atom.coords[i] < min.unsafe_fetch(i)
          max[i] = atom.coords[i] if atom.coords[i] > max.unsafe_fetch(i)
        end
      end
      origin = Spatial::Vector.new min[0], min[1], min[2]
      size = Spatial::Size3D.new max[0] - min[0], max[1] - min[1], max[2] - min[2]
      Spatial::Bounds.new origin, size
    end

    def each_atom(&block : Atom ->)
      each_atom.each &block
    end

    def formal_charge : Int32
      each_atom.sum &.charge
    end

    def formal_charges : Array(Int32)
      each_atom.map(&.charge).to_a
    end
  end
end
