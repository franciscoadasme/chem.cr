require "../spec_helper"

describe Chem::Spatial::CoordinatesProxy do
  structure = Chem::Structure.build do
    lattice 10, 10, 10

    atom PeriodicTable::O, V[1, 2, 3]
    atom PeriodicTable::H, V[4, 5, 6]
    atom PeriodicTable::H, V[7, 8, 9]
  end

  describe "#bounds" do
    it "returns the bounds" do
      bounds = structure.coords.bounds
      bounds.origin.should eq V[1, 2, 3]
      bounds.size.should eq S[6, 6, 6]
    end
  end

  describe "#center" do
    it "returns the geometric center" do
      structure.coords.center.should eq V[4, 5, 6]
    end
  end

  describe "#each" do
    it "yields the coordinates of every atom" do
      vecs = [] of V
      structure.coords.each { |coords| vecs << coords }
      vecs.should eq [V[1, 2, 3], V[4, 5, 6], V[7, 8, 9]]
    end

    it "yields the fractional coordinates of every atom" do
      vecs = [] of V
      structure.coords.each(fractional: true) { |fcoords| vecs << fcoords }

      expected = [V[0.1, 0.2, 0.3], V[0.4, 0.5, 0.6], V[0.7, 0.8, 0.9]]
      vecs.should be_close expected, 1e-15
    end

    it "returns an iterator of coordinates" do
      structure.coords.each.to_a.should eq [V[1, 2, 3], V[4, 5, 6], V[7, 8, 9]]
    end

    it "returns an iterator of fractional coordinates" do
      structure.coords.each(fractional: true).to_a.should be_close [
        V[0.1, 0.2, 0.3], V[0.4, 0.5, 0.6], V[0.7, 0.8, 0.9],
      ], 1e-15
    end

    it "fails for a non-periodic atom collection" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.coords.each(fractional: true) { }
      end
    end
  end

  describe "#each_with_atom" do
    it "yields coordinates and the corresponding atom" do
      elements = [] of String
      vecs = [] of Vector
      structure.coords.each_with_atom do |coords, atom|
        vecs << coords
        elements << atom.element.symbol
      end
      vecs.should eq [V[1, 2, 3], V[4, 5, 6], V[7, 8, 9]]
      elements.should eq ["O", "H", "H"]
    end

    it "yields the fractional coordinates of every atom" do
      elements = [] of String
      vecs = [] of V
      structure.coords.each_with_atom(fractional: true) do |fcoords, atom|
        vecs << fcoords
        elements << atom.element.symbol
      end

      expected = [V[0.1, 0.2, 0.3], V[0.4, 0.5, 0.6], V[0.7, 0.8, 0.9]]
      vecs.should be_close expected, 1e-15
      elements.should eq ["O", "H", "H"]
    end

    it "fails for a non-periodic atom collection" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.coords.each(fractional: true) { }
      end
    end
  end

  describe "#map" do
    it "returns the modified atom coordinates" do
      expected = [V[2, 4, 6], V[8, 10, 12], V[14, 16, 18]]
      structure.coords.map(&.*(2)).should eq expected
    end

    it "returns the modified fractional atom coordinates" do
      expected = [V[0.2, 0.4, 0.6], V[0.8, 1.0, 1.2], V[1.4, 1.6, 1.8]]
      structure.coords.map(fractional: true, &.*(2)).should be_close expected, 1e-15
    end

    it "fails for a non-periodic atom collection" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.coords.map fractional: true, &.itself
      end
    end
  end

  describe "#map!" do
    it "modifies the atom coordinates" do
      other = Chem::Structure.build do
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end

      other.coords.map!(&.*(2)).should eq [V[2, 4, 6], V[8, 10, 12], V[14, 16, 18]]
    end

    it "modifies the fractional atom coordinates" do
      other = Chem::Structure.build do
        lattice 5, 10, 15
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end
      expected = [V[6, 12, 18], V[9, 15, 21], V[12, 18, 24]]

      other.coords.map!(fractional: true, &.+(1)).should be_close expected, 1e-12
    end

    it "fails for a non-periodic atom collection" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.coords.map! fractional: true, &.itself
      end
    end
  end

  describe "#map_with_atom" do
    it "returns the modified atom coordinates" do
      expected = [V[2, 4, 6], V[4, 5, 6], V[7, 8, 9]]
      coords = structure.coords.map_with_atom do |vec, atom|
        vec * (atom.element.hydrogen? ? 1 : 2)
      end
      coords.should eq expected
    end

    it "returns the modified fractional atom coordinates" do
      expected = [V[0.2, 0.4, 0.6], V[0.4, 0.5, 0.6], V[0.7, 0.8, 0.9]]
      coords = structure.coords.map_with_atom(fractional: true) do |vec, atom|
        vec * (atom.element.hydrogen? ? 1 : 2)
      end
      coords.should be_close expected, 1e-15
    end

    it "fails for a non-periodic atom collection" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.coords.map_with_atom fractional: true, &.itself
      end
    end
  end

  describe "#map_with_atom!" do
    it "modifies the atom coordinates" do
      other = Chem::Structure.build do
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end

      other.coords.map_with_atom! { |vec, atom| vec * (atom.element.hydrogen? ? 1 : 3) }
      other.coords.should eq [V[3, 6, 9], V[4, 5, 6], V[7, 8, 9]]
    end

    it "modifies the fractional atom coordinates" do
      other = Chem::Structure.build do
        lattice 5, 10, 15
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end
      expected = [V[6, 12, 18], V[4, 5, 6], V[7, 8, 9]]

      other.coords.map_with_atom!(fractional: true) do |vec, atom|
        vec + (atom.element.hydrogen? ? 0 : 1)
      end
      other.coords.should be_close expected, 1e-12
    end

    it "fails for a non-periodic atom collection" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.coords.map_with_atom! fractional: true, &.itself
      end
    end
  end

  describe "#transform" do
    it "returns the transformed atom coordinates" do
      transform = Tf.translation by: V[3, 2, 1]
      expected = [V[4, 4, 4], V[7, 7, 7], V[10, 10, 10]]
      structure.coords.transform(transform).should eq expected
    end
  end

  describe "#transform!" do
    it "transforms the atom coordinates" do
      other = Chem::Structure.build do
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end

      transform = Tf.translation by: V[-1, 0, 1]
      other.coords.transform!(transform).should eq [V[0, 2, 4], V[3, 5, 7], V[6, 8, 10]]
    end
  end

  describe "#translate" do
    it "returns the translated atom coordinates" do
      expected = [V[-1, 0, 1], V[2, 3, 4], V[5, 6, 7]]
      structure.coords.translate(by: V[-2, -2, -2]).should eq expected
    end
  end

  describe "#translate!" do
    it "translates the atom coordinates" do
      other = Chem::Structure.build do
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end

      expected = [V[-2, 0, 2], V[1, 3, 5], V[4, 6, 8]]
      other.coords.translate!(by: V[-3, -2, -1]).should eq expected
    end
  end

  describe "#to_a" do
    it "returns the coordinates of the atoms" do
      structure.coords.to_a.should eq [V[1, 2, 3], V[4, 5, 6], V[7, 8, 9]]
    end

    it "returns the fractional coordinates of the atoms" do
      expected = [V[0.1, 0.2, 0.3], V[0.4, 0.5, 0.6], V[0.7, 0.8, 0.9]]
      structure.coords.to_a(fractional: true).should be_close expected, 1e-15
    end

    it "fails for a non-periodic atom collection" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.coords.to_a fractional: true
      end
    end
  end

  describe "#to_cartesian!" do
    it "transforms fractional coordinates to Cartesian" do
      structure = Chem::Structure.build do
        lattice 10, 20, 30
        atom PeriodicTable::O, V[0.2, 0.4, 0.6]
        atom PeriodicTable::H, V[0.1, 0.2, 0.3]
        atom PeriodicTable::H, V[0.6, 0.9, 0.35]
      end

      expected = [V[2, 8, 18], V[1, 4, 9], V[6, 18, 10.5]]
      structure.coords.to_cartesian!.should be_close expected, 1e-15
    end
  end

  describe "#to_fractional!" do
    it "transforms Cartesian coordinates to fractional" do
      structure = Chem::Structure.build do
        lattice 10, 20, 30
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end

      expected = [V[0.1, 0.1, 0.1], V[0.4, 0.25, 0.2], V[0.7, 0.4, 0.3]]
      structure.coords.to_fractional!.should be_close expected, 1e-15
    end
  end

  describe "#wrap" do
    it "wraps atoms into the primary unit cell" do
      coords = Chem::Structure.read("spec/data/poscar/AlaIle--unwrapped.poscar").coords
      coords.wrap

      expected = Chem::Structure.read("spec/data/poscar/AlaIle--wrapped.poscar").coords
      coords.should be_close expected, 1e-15
    end

    it "wraps atoms into the primary unit cell in a non-rectangular lattice" do
      coords = Chem::Structure.read("spec/data/poscar/5e61--unwrapped.poscar").coords
      coords.wrap

      expected = Chem::Structure.read("spec/data/poscar/5e61--wrapped.poscar").coords
      coords.should be_close expected, 1e-3
    end

    it "wraps atoms into the primary unit cell centered at the origin" do
      coords = Chem::Structure.read("spec/data/poscar/5e61--unwrapped.poscar").coords
      coords.wrap around: V.origin

      expected = Chem::Structure.read("spec/data/poscar/5e61--wrapped--origin.poscar").coords
      coords.should be_close expected, 1e-3
    end
  end
end
