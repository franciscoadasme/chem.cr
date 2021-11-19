require "../spec_helper"

describe Chem::Spatial::PBC do
  describe "#each_adjacent_image" do
    it "yields each atom in the adjacent periodic images" do
      structure = Chem::Structure.build do
        cell 10, 10, 10

        atom :C, Chem::Spatial::Vec3[2.5, 2.5, 2.5]
        atom :H, Chem::Spatial::Vec3[7.5, 2.5, 2.5]
        atom :O, Chem::Spatial::Vec3[2.5, 7.5, 2.5]
        atom :N, Chem::Spatial::Vec3[2.5, 2.5, 7.5]
      end

      vectors = Chem::Spatial::PBC.adjacent_images(structure).map &.[1]
      expected = [
        [12.5, 2.5, 2.5], [2.5, 12.5, 2.5], [2.5, 2.5, 12.5], [12.5, 12.5, 2.5],
        [12.5, 2.5, 12.5], [2.5, 12.5, 12.5], [12.5, 12.5, 12.5], [-2.5, 2.5, 2.5],
        [7.5, 12.5, 2.5], [7.5, 2.5, 12.5], [-2.5, 12.5, 2.5], [-2.5, 2.5, 12.5],
        [7.5, 12.5, 12.5], [-2.5, 12.5, 12.5], [12.5, 7.5, 2.5], [2.5, -2.5, 2.5],
        [2.5, 7.5, 12.5], [12.5, -2.5, 2.5], [12.5, 7.5, 12.5], [2.5, -2.5, 12.5],
        [12.5, -2.5, 12.5], [12.5, 2.5, 7.5], [2.5, 12.5, 7.5], [2.5, 2.5, -2.5],
        [12.5, 12.5, 7.5], [12.5, 2.5, -2.5], [2.5, 12.5, -2.5], [12.5, 12.5, -2.5],
      ]
      vectors.should eq expected
    end

    it "yields each atom in the adjacent periodic images for non-centered structure" do
      offset = Chem::Spatial::Vec3[-20, 10, 30]

      structure = Chem::Structure.build do
        cell 10, 10, 10

        atom :C, Chem::Spatial::Vec3[2.5, 2.5, 2.5]
        atom :H, Chem::Spatial::Vec3[7.5, 2.5, 2.5]
        atom :O, Chem::Spatial::Vec3[2.5, 7.5, 2.5]
        atom :N, Chem::Spatial::Vec3[2.5, 2.5, 7.5]
      end
      structure.coords.translate! by: offset

      vectors = Chem::Spatial::PBC.adjacent_images(structure).map &.[1]
      expected = [
        [12.5, 2.5, 2.5], [2.5, 12.5, 2.5], [2.5, 2.5, 12.5], [12.5, 12.5, 2.5],
        [12.5, 2.5, 12.5], [2.5, 12.5, 12.5], [12.5, 12.5, 12.5], [-2.5, 2.5, 2.5],
        [7.5, 12.5, 2.5], [7.5, 2.5, 12.5], [-2.5, 12.5, 2.5], [-2.5, 2.5, 12.5],
        [7.5, 12.5, 12.5], [-2.5, 12.5, 12.5], [12.5, 7.5, 2.5], [2.5, -2.5, 2.5],
        [2.5, 7.5, 12.5], [12.5, -2.5, 2.5], [12.5, 7.5, 12.5], [2.5, -2.5, 12.5],
        [12.5, -2.5, 12.5], [12.5, 2.5, 7.5], [2.5, 12.5, 7.5], [2.5, 2.5, -2.5],
        [12.5, 12.5, 7.5], [12.5, 2.5, -2.5], [2.5, 12.5, -2.5], [12.5, 12.5, -2.5],
      ].map { |(x, y, z)| Chem::Spatial::Vec3[x, y, z] + offset }
      vectors.should eq expected
    end

    it "yields each atom in the adjacent periodic images within the given radius" do
      structure = Chem::Structure.build do
        cell 10, 10, 10

        atom :C, Chem::Spatial::Vec3[1, 8.5, 3.5]
        atom :H, Chem::Spatial::Vec3[7.5, 1.5, 9.5]
      end

      vectors = Chem::Spatial::PBC.adjacent_images(structure, radius: 2).map(&.[1]).sort_by! &.to_a
      expected = [
        [11, 8.5, 3.5], [1, -1.5, 3.5], [11, -1.5, 3.5],
        [7.5, 11.5, 9.5], [7.5, 1.5, -0.5], [7.5, 11.5, -0.5],
      ].sort_by! &.to_a
      vectors.size.should eq expected.size
      vectors.should be_close expected, 1e-8
    end

    it "yields periodic images within cutoff for a off-center non-orthogonal cell" do
      structure = load_file "5e61--off-center.poscar"
      cell = structure.cell.not_nil!
      atoms = structure.atoms

      vectors = Chem::Spatial::PBC.adjacent_images(structure, radius: 2)
        .select! { |atom, _|
          {17, 30, 66, 116, 127, 175, 188, 193}.includes?(atom.serial)
        }
        .map(&.[1])
        .sort_by!(&.to_a)

      expected = [
        atoms[29].coords.image(cell, 0, 0, 1),
        atoms[29].coords.image(cell, -1, 0, 0),
        atoms[29].coords.image(cell, -1, 0, 1),
        atoms[65].coords.image(cell, 0, -1, -1),
        atoms[65].coords.image(cell, 0, -1, 0),
        atoms[65].coords.image(cell, 0, 0, -1),
        atoms[65].coords.image(cell, 1, -1, -1),
        atoms[65].coords.image(cell, 1, -1, 0),
        atoms[65].coords.image(cell, 1, 0, 0),
        atoms[65].coords.image(cell, 1, 0, -1),
        atoms[115].coords.image(cell, -1, 0, 0),
        atoms[115].coords.image(cell, -1, 0, 1),
        atoms[115].coords.image(cell, -1, 1, 0),
        atoms[115].coords.image(cell, -1, 1, 1),
        atoms[115].coords.image(cell, 0, 0, 1),
        atoms[115].coords.image(cell, 0, 1, 0),
        atoms[115].coords.image(cell, 0, 1, 1),
        atoms[126].coords.image(cell, 1, 0, 0),
        atoms[174].coords.image(cell, -1, 0, 0),
        atoms[174].coords.image(cell, -1, 1, 0),
        atoms[174].coords.image(cell, 0, 1, 0),
        atoms[187].coords.image(cell, -1, 0, 0),
        atoms[187].coords.image(cell, -1, 0, 1),
        atoms[187].coords.image(cell, 0, 0, 1),
        atoms[192].coords.image(cell, 0, -1, 0),
        atoms[192].coords.image(cell, 1, -1, 0),
        atoms[192].coords.image(cell, 1, 0, 0),
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
      structure.cell = Chem::UnitCell.new({10, 10, 10})
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
      structure.atoms.map(&.coords).should be_close expected.atoms.map(&.coords), 1e-2
    end
  end
end
