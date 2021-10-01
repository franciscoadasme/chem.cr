require "../spec_helper"

describe Chem::Spatial::PBC do
  describe "#each_adjacent_image" do
    it "yields each atom in the adjacent periodic images" do
      structure = Chem::Structure.build(guess_topology: false) do
        lattice 10, 10, 10

        atom :C, V[2.5, 2.5, 2.5]
        atom :H, V[7.5, 2.5, 2.5]
        atom :O, V[2.5, 7.5, 2.5]
        atom :N, V[2.5, 2.5, 7.5]
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

      structure = Chem::Structure.build(guess_topology: false) do
        lattice 10, 10, 10

        atom :C, V[2.5, 2.5, 2.5]
        atom :H, V[7.5, 2.5, 2.5]
        atom :O, V[2.5, 7.5, 2.5]
        atom :N, V[2.5, 2.5, 7.5]
      end
      structure.coords.translate! by: offset

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
      structure = Chem::Structure.build(guess_topology: false) do
        lattice 10, 10, 10

        atom :C, V[1, 8.5, 3.5]
        atom :H, V[7.5, 1.5, 9.5]
      end

      vectors = PBC.adjacent_images(structure, radius: 2).map(&.[1]).sort_by! &.to_a
      expected = [
        V[11, 8.5, 3.5], V[1, -1.5, 3.5], V[11, -1.5, 3.5],
        V[7.5, 11.5, 9.5], V[7.5, 1.5, -0.5], V[7.5, 11.5, -0.5],
      ].sort_by! &.to_a
      vectors.size.should eq expected.size
      vectors.should be_close expected, 1e-8
    end

    it "yields periodic images within cutoff for a off-center non-orthogonal lattice" do
      structure = load_file "5e61--off-center.poscar"
      lattice = structure.lattice.not_nil!
      atoms = structure.atoms

      vectors = PBC.adjacent_images(structure, radius: 2)
        .select! { |atom, _|
          {17, 30, 66, 116, 127, 175, 188, 193}.includes?(atom.serial)
        }
        .map(&.[1])
        .sort_by!(&.to_a)

      expected = [
        atoms[29].coords.image(lattice, 0, 0, 1),
        atoms[29].coords.image(lattice, -1, 0, 0),
        atoms[29].coords.image(lattice, -1, 0, 1),
        atoms[65].coords.image(lattice, 0, -1, -1),
        atoms[65].coords.image(lattice, 0, -1, 0),
        atoms[65].coords.image(lattice, 0, 0, -1),
        atoms[65].coords.image(lattice, 1, -1, -1),
        atoms[65].coords.image(lattice, 1, -1, 0),
        atoms[65].coords.image(lattice, 1, 0, 0),
        atoms[65].coords.image(lattice, 1, 0, -1),
        atoms[115].coords.image(lattice, -1, 0, 0),
        atoms[115].coords.image(lattice, -1, 0, 1),
        atoms[115].coords.image(lattice, -1, 1, 0),
        atoms[115].coords.image(lattice, -1, 1, 1),
        atoms[115].coords.image(lattice, 0, 0, 1),
        atoms[115].coords.image(lattice, 0, 1, 0),
        atoms[115].coords.image(lattice, 0, 1, 1),
        atoms[126].coords.image(lattice, 1, 0, 0),
        atoms[174].coords.image(lattice, -1, 0, 0),
        atoms[174].coords.image(lattice, -1, 1, 0),
        atoms[174].coords.image(lattice, 0, 1, 0),
        atoms[187].coords.image(lattice, -1, 0, 0),
        atoms[187].coords.image(lattice, -1, 0, 1),
        atoms[187].coords.image(lattice, 0, 0, 1),
        atoms[192].coords.image(lattice, 0, -1, 0),
        atoms[192].coords.image(lattice, 1, -1, 0),
        atoms[192].coords.image(lattice, 1, 0, 0),
      ].sort_by!(&.to_a)
      vectors.size.should eq expected.size
      vectors.should be_close expected, 1e-6
    end

    it "fails for non-periodic structures" do
      expect_raises Chem::Spatial::NotPeriodicError do
        Chem::Spatial::PBC.each_adjacent_image(fake_structure) { }
      end
    end

    it "fails when radius is negative" do
      structure = Chem::Structure.new
      structure.lattice = Lattice.new S[10, 10, 10]
      expect_raises Chem::Spatial::Error, "Radius cannot be negative" do
        Chem::Spatial::PBC.each_adjacent_image(structure, radius: -2) { }
      end
    end
  end

  describe "#unwrap" do
    it "unwraps a structure" do
      structure = load_file "5e61--wrapped.poscar"
      structure.unwrap
      expected = load_file "5e61--unwrapped.poscar"
      structure.atoms.map(&.coords).should be_close expected.atoms.map(&.coords), 1e-3
    end

    it "unwraps a structure placing fragments close together" do
      structure = load_file "5e5v--wrapped.poscar"
      structure.unwrap
      expected = load_file "5e5v--unwrapped.poscar"
      structure.atoms.map(&.coords).should be_close expected.atoms.map(&.coords), 1e-3
    end
  end
end
