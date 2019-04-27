require "../spec_helper"

describe Chem::Spatial::PBC do
  describe "#each_adjacent_image" do
    it "yields each atom in the adjacent periodic images" do
      structure = Chem::Structure.build do
        lattice 10, 10, 10

        atom PeriodicTable::C, at: V[2.5, 2.5, 2.5]
        atom PeriodicTable::H, at: V[7.5, 2.5, 2.5]
        atom PeriodicTable::O, at: V[2.5, 7.5, 2.5]
        atom PeriodicTable::N, at: V[2.5, 2.5, 7.5]
      end

      vectors = Chem::Spatial::PBC.adjacent_images(structure).map &.[1]
      expected = [
        V[12.5, 2.5, 2.5], V[2.5, 12.5, 2.5], V[2.5, 2.5, 12.5], V[12.5, 12.5, 2.5],
        V[12.5, 2.5, 12.5], V[2.5, 12.5, 12.5], V[12.5, 12.5, 12.5], V[-2.5, 2.5, 2.5],
        V[7.5, 12.5, 2.5], V[7.5, 2.5, 12.5], V[-2.5, 12.5, 2.5], V[-2.5, 2.5, 12.5],
        V[7.5, 12.5, 12.5], V[-2.5, 12.5, 12.5], V[12.5, 7.5, 2.5], V[2.5, -2.5, 2.5],
        V[2.5, 7.5, 12.5], V[12.5, -2.5, 2.5], V[12.5, 7.5, 12.5], V[2.5, -2.5, 12.5],
        V[12.5, -2.5, 12.5], V[12.5, 2.5, 7.5], V[2.5, 12.5, 7.5], V[2.5, 2.5, -2.5],
        V[12.5, 12.5, 7.5], V[12.5, 2.5, -2.5], V[2.5, 12.5, -2.5], V[12.5, 12.5, -2.5],
      ]
      vectors.should eq expected
    end

    it "yields each atom in the adjacent periodic images for non-centered structure" do
      offset = V[-20, 10, 30]

      structure = Chem::Structure.build do
        lattice 10, 10, 10

        atom PeriodicTable::C, at: V[2.5, 2.5, 2.5]
        atom PeriodicTable::H, at: V[7.5, 2.5, 2.5]
        atom PeriodicTable::O, at: V[2.5, 7.5, 2.5]
        atom PeriodicTable::N, at: V[2.5, 2.5, 7.5]
      end
      structure.translate! by: offset

      vectors = Chem::Spatial::PBC.adjacent_images(structure).map &.[1]
      expected = [
        V[12.5, 2.5, 2.5], V[2.5, 12.5, 2.5], V[2.5, 2.5, 12.5], V[12.5, 12.5, 2.5],
        V[12.5, 2.5, 12.5], V[2.5, 12.5, 12.5], V[12.5, 12.5, 12.5], V[-2.5, 2.5, 2.5],
        V[7.5, 12.5, 2.5], V[7.5, 2.5, 12.5], V[-2.5, 12.5, 2.5], V[-2.5, 2.5, 12.5],
        V[7.5, 12.5, 12.5], V[-2.5, 12.5, 12.5], V[12.5, 7.5, 2.5], V[2.5, -2.5, 2.5],
        V[2.5, 7.5, 12.5], V[12.5, -2.5, 2.5], V[12.5, 7.5, 12.5], V[2.5, -2.5, 12.5],
        V[12.5, -2.5, 12.5], V[12.5, 2.5, 7.5], V[2.5, 12.5, 7.5], V[2.5, 2.5, -2.5],
        V[12.5, 12.5, 7.5], V[12.5, 2.5, -2.5], V[2.5, 12.5, -2.5], V[12.5, 12.5, -2.5],
      ].map &.+(offset)
      vectors.should eq expected
    end

    it "yields each atom in the adjacent periodic images within the given radius" do
      structure = Chem::Structure.build do
        lattice 10, 10, 10

        atom PeriodicTable::C, at: V[1, 8.5, 3.5]
        atom PeriodicTable::H, at: V[7.5, 1.5, 9.5]
      end

      vectors = Chem::Spatial::PBC.adjacent_images(structure, radius: 2).map &.[1]
      expected = [
        V[11, 8.5, 3.5], V[1, -1.5, 3.5], V[11, -1.5, 3.5],
        V[7.5, 11.5, 9.5], V[7.5, 1.5, -0.5], V[7.5, 11.5, -0.5],
      ]
      vectors.should be_close expected, 1e-8
    end

    it "fails for non-periodic structures" do
      msg = "Cannot generate adjacent images of a non-periodic structure"
      expect_raises Chem::Spatial::Error, msg do
        Chem::Spatial::PBC.each_adjacent_image(fake_structure) { }
      end
    end

    it "fails when radius is negative" do
      structure = Chem::Structure.build { lattice 10, 10, 10 }
      expect_raises Chem::Spatial::Error, "Radius cannot be negative" do
        Chem::Spatial::PBC.each_adjacent_image(structure, radius: -2) { }
      end
    end
  end

  describe "#wrap" do
    it "wraps atoms into the primary unit cell" do
      st = Chem::Structure.read "spec/data/poscar/AlaIle--unwrapped.poscar"
      st.wrap

      expected = Chem::Structure.read "spec/data/poscar/AlaIle--wrapped.poscar"
      st.each_atom.zip(expected.each_atom).each do |a, b|
        a.coords.should be_close b.coords, 1e-15
      end
    end

    it "wraps atoms into the primary unit cell in a non-rectangular lattice" do
      st = Chem::Structure.read "spec/data/poscar/5e61--unwrapped.poscar"
      st.wrap

      expected = Chem::Structure.read "spec/data/poscar/5e61--wrapped.poscar"
      st.each_atom.zip(expected.each_atom).each do |a, b|
        a.coords.should be_close b.coords, 1e-3
      end
    end

    it "wraps atoms into the primary unit cell centered at the origin" do
      st = Chem::Structure.read "spec/data/poscar/5e61--unwrapped.poscar"
      st.wrap around: V.origin

      expected = Chem::Structure.read "spec/data/poscar/5e61--wrapped--origin.poscar"
      st.each_atom.zip(expected.each_atom).each do |a, b|
        a.coords.should be_close b.coords, 1e-3
      end
    end
  end
end
