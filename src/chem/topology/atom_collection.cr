module Chem
  module AtomCollection
    abstract def each_atom : Iterator(Atom)
    abstract def each_atom(&block : Atom ->)

    def atoms : AtomView
      atoms = [] of Atom
      each_atom { |atom| atoms << atom }
      AtomView.new atoms
    end

    def bonds : Array(Bond)
      bonds = Set(Bond).new
      each_atom { |atom| bonds.concat atom.bonds }
      bonds.to_a
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

    def coords : Spatial::CollectionProxy
      Spatial::CollectionProxy.new self
    end

    def formal_charge : Int32
      each_atom.sum &.formal_charge
    end

    def formal_charges : Array(Int32)
      each_atom.map(&.formal_charge).to_a
    end

    def transform(by transform : Spatial::AffineTransform) : self
      each_atom do |atom|
        atom.coords *= transform
      end
      self
    end

    def translate!(by vector : Spatial::Vector)
      each_atom do |atom|
        atom.coords += vector
      end
    end
  end
end
