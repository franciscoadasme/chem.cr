require "../spec_helper"

describe Chem::Spatial::CoordinatesProxy do
  structure = Chem::Structure.build do
    cell 10, 10, 10

    atom Chem::PeriodicTable::O, vec3(1, 2, 3)
    atom Chem::PeriodicTable::H, vec3(4, 5, 6)
    atom Chem::PeriodicTable::H, vec3(7, 8, 9)
  end

  describe "#align_to" do
    it "aligns coordinates to a reference" do
      s = Array(Chem::Structure).read spec_file("E20_conformers.mol2")
      ref_pos = s[0].pos
      s[1].pos.align_to(ref_pos).rmsd(ref_pos).should be_close 3.463298, 1e-6
      s[2].pos.align_to(ref_pos).rmsd(ref_pos).should be_close 1.818679, 1e-6
      s[3].pos.align_to(ref_pos).rmsd(ref_pos).should be_close 3.845655, 1e-6
      s[4].pos.align_to(ref_pos).rmsd(ref_pos).should be_close 1.475276, 1e-6
    end
  end

  describe "#bounds" do
    it "returns the bounds" do
      bounds = structure.pos.bounds
      bounds.origin.should eq [1, 2, 3]
      bounds.size.should eq [6, 6, 6]
    end
  end

  describe "#center" do
    it "returns the geometric center" do
      structure.pos.center.should eq [4, 5, 6]
    end
  end

  describe "#center_along" do
    it "centers at the middle point of a vector" do
      structure.clone.pos.center_along(vec3(0, 0, 10)).center.should eq [4, 5, 5]
    end
  end

  describe "#center_at" do
    it "centers at the given vector" do
      structure.clone.pos.center_at(vec3(2.5, 3, 0)).center.should eq [2.5, 3, 0]
    end
  end

  describe "#center_at_cell" do
    it "centers at the primary unit cell" do
      structure.clone.pos.center_at_cell.center.should eq [5, 5, 5]
    end
  end

  describe "#center_at_origin" do
    it "centers at the origin" do
      structure.clone.pos.center_at_origin.center.should eq [0, 0, 0]
    end
  end

  describe "#com" do
    it "returns center of mass" do
      structure.pos.com.should be_close [1.5035248, 2.5035248, 3.5035248], 1e-6
    end
  end

  describe "#each" do
    it "yields the coordinates of every atom" do
      vecs = [] of Chem::Spatial::Vec3
      structure.pos.each { |pos| vecs << pos }
      vecs.should eq [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    end

    it "yields the fractional coordinates of every atom" do
      vecs = [] of Chem::Spatial::Vec3
      structure.pos.each(fractional: true) { |fpos| vecs << fpos }

      expected = [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6], [0.7, 0.8, 0.9]]
      vecs.should be_close expected, 1e-15
    end

    it "returns an iterator of coordinates" do
      structure.pos.each.to_a.should eq [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    end

    it "returns an iterator of fractional coordinates" do
      structure.pos.each(fractional: true).to_a.should be_close [
        [0.1, 0.2, 0.3], [0.4, 0.5, 0.6], [0.7, 0.8, 0.9],
      ], 1e-15
    end

    it "fails for a non-periodic structure" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.pos.each(fractional: true) { }
      end
    end
  end

  describe "#each_with_atom" do
    it "yields coordinates and the corresponding atom" do
      elements = [] of String
      vecs = [] of Chem::Spatial::Vec3
      structure.pos.each_with_atom do |pos, atom|
        vecs << pos
        elements << atom.element.symbol
      end
      vecs.should eq [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      elements.should eq ["O", "H", "H"]
    end

    it "yields the fractional coordinates of every atom" do
      elements = [] of String
      vecs = [] of Chem::Spatial::Vec3
      structure.pos.each_with_atom(fractional: true) do |fpos, atom|
        vecs << fpos
        elements << atom.element.symbol
      end

      expected = [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6], [0.7, 0.8, 0.9]]
      vecs.should be_close expected, 1e-15
      elements.should eq ["O", "H", "H"]
    end

    it "fails for a non-periodic structure" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.pos.each(fractional: true) { }
      end
    end
  end

  describe "#map!" do
    it "modifies the atom coordinates" do
      other = Chem::Structure.build do
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end

      other.pos.map!(&.*(2)).should eq [[2, 4, 6], [8, 10, 12], [14, 16, 18]]
    end

    it "modifies the fractional atom coordinates" do
      other = Chem::Structure.build do
        cell 5, 10, 15
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end
      expected = [[6, 12, 18], [9, 15, 21], [12, 18, 24]]

      other.pos.map!(fractional: true, &.+(1)).should be_close expected, 1e-12
    end

    it "fails for a non-periodic structure" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.pos.map! fractional: true, &.itself
      end
    end
  end

  describe "#map_with_atom!" do
    it "modifies the atom coordinates" do
      other = Chem::Structure.build do
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end

      other.pos.map_with_atom! { |vec, atom| vec * (atom.element.hydrogen? ? 1 : 3) }
      other.pos.should eq [[3, 6, 9], [4, 5, 6], [7, 8, 9]]
    end

    it "modifies the fractional atom coordinates" do
      other = Chem::Structure.build do
        cell 5, 10, 15
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end
      expected = [[6, 12, 18], [4, 5, 6], [7, 8, 9]]

      other.pos.map_with_atom!(fractional: true) do |vec, atom|
        vec + (atom.element.hydrogen? ? 0 : 1)
      end
      other.pos.should be_close expected, 1e-12
    end

    it "fails for a non-periodic structure" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.pos.map_with_atom! fractional: true, &.itself
      end
    end
  end

  describe ".rdgyr" do
    it "computes the rdgyr in-place" do
      s = Chem::Structure.read spec_file("FAD_can_prep.pdb")
      s.pos.rdgyr.should be_close 6.339020, 1e-6
    end
  end

  describe ".rmsd" do
    it "computes the rmsd in-place" do
      s = Array(Chem::Structure).read spec_file("E20_conformers.mol2")
      s[1].pos.rmsd(s[0].pos).should be_close 7.933736, 1e-6
      s[2].pos.rmsd(s[0].pos).should be_close 2.607424, 1e-6
      s[3].pos.rmsd(s[0].pos).should be_close 8.177316, 1e-6
      s[4].pos.rmsd(s[0].pos).should be_close 1.815176, 1e-6
    end

    it "computes the rmsd in-place with weights" do
      s = Array(Chem::Structure).read spec_file("E20_conformers.mol2")
      weights = s[0].atoms.map &.mass
      s[1].pos.rmsd(s[0].pos, weights).should be_close 8.187659, 1e-6
      s[2].pos.rmsd(s[0].pos, weights).should be_close 2.265467, 1e-6
      s[3].pos.rmsd(s[0].pos, weights).should be_close 7.955341, 1e-6
      s[4].pos.rmsd(s[0].pos, weights).should be_close 1.510461, 1e-6
    end

    it "computes the minimum rmsd" do
      s = Array(Chem::Structure).read spec_file("E20_conformers.mol2")
      s[1].pos.rmsd(s[0].pos, minimize: true).should be_close 3.463298, 1e-6
      s[2].pos.rmsd(s[0].pos, minimize: true).should be_close 1.818679, 1e-6
      s[3].pos.rmsd(s[0].pos, minimize: true).should be_close 3.845655, 1e-6
      s[4].pos.rmsd(s[0].pos, minimize: true).should be_close 1.475276, 1e-6
    end

    it "computes the minimum rmsd with weights" do
      s = Array(Chem::Structure).read spec_file("E20_conformers.mol2")
      weights = s[0].atoms.map &.mass
      s[1].pos.rmsd(s[0].pos, weights, minimize: true).should be_close 2.811033, 1e-6
      s[2].pos.rmsd(s[0].pos, weights, minimize: true).should be_close 1.358219, 1e-6
      s[3].pos.rmsd(s[0].pos, weights, minimize: true).should be_close 3.067433, 1e-6
      s[4].pos.rmsd(s[0].pos, weights, minimize: true).should be_close 1.084173, 1e-6
    end
  end

  describe "#rotate" do
    it "rotates the coordinates" do
      water = Chem::Structure.read spec_file("waters.xyz")
      pos = water.pos.to_a
      transform = Chem::Spatial::Transform.translation(-pos.mean)
        .rotate(90, 150, 2).translate(pos.mean)
      water.dup.pos.rotate(90, 150, 2).should eq pos.map(&.transform(transform))
    end

    it "rotates the coordinates centered at point" do
      water = Chem::Structure.read spec_file("waters.xyz")
      pos = water.pos.to_a
      pivot = Chem::Spatial::Vec3.zero
      water.dup.pos.rotate(78, 25, 10, pivot).should eq pos.map(&.rotate(78, 25, 10))
    end
  end

  describe "#transform" do
    it "transforms the atom coordinates" do
      other = Chem::Structure.build do
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end

      transform = Chem::Spatial::Transform.translation vec3(-1, 0, 1)
      other.pos.transform(transform).should eq [[0, 2, 4], [3, 5, 7], [6, 8, 10]]
    end

    it "rotates and translates atom coordinates" do
      other = Chem::Structure.build do
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end
      center = other.pos.center
      transform = Chem::Spatial::Transform.rotation(10, 50, 15).translate(vec3(1, 2, 3))
      expected = other.pos.to_a.map { |vec| transform * vec }
      other.pos.transform(transform).should eq expected
    end

    it "aligns by a subset (#183)" do
      actual = Chem::Structure.from_pdb spec_file("pr183_actual.pdb")
      ref = Chem::Structure.from_pdb spec_file("pr183_ref.pdb")

      atoms, ref_atoms = {actual, ref}.map do |s|
        Chem::AtomView.new [52, 2, 12, 22, 32, 42].map { |i| s.atoms[i] }
      end
      tr = Chem::Spatial::Transform.aligning(atoms, to: ref_atoms)
      actual.pos.transform tr
      atoms.pos.rmsd(ref_atoms.pos).should be_close 0.091, 1e-3
    end

    it "aligns to an axis (#183)" do
      sf = Chem::Structure.from_pdb spec_file("pr183_7M2I_sf-helice--aligned.pdb")
      ks = sf.atoms.select(&.potassium?)
      sf.pos.translate -ks.mean(&.pos)

      # compute center of selected oxygens and set Y component to 0
      os = (75..78).map { |i| sf.chains.first.dig(i, "O") }
      oc = os.mean(&.pos).reject(Chem::Spatial::Vec3[0, 1, 0]).normalize
      transform = Chem::Spatial::Transform.aligning oc, to: Chem::Spatial::Vec3[1, 0, 0]
      sf.pos.transform transform
      os.mean(&.pos).should be_close Chem::Spatial::Vec3[2.348, 1.756, 0], 1e-3
    end
  end

  describe "#translate" do
    it "translates the atom coordinates" do
      other = Chem::Structure.build do
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end

      expected = [[-2, 0, 2], [1, 3, 5], [4, 6, 8]]
      other.pos.translate(by: vec3(-3, -2, -1)).should eq expected
    end
  end

  describe "#to_a" do
    it "returns the coordinates of the atoms" do
      structure.pos.to_a.should eq [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    end

    it "returns the fractional coordinates of the atoms" do
      expected = [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6], [0.7, 0.8, 0.9]]
      structure.pos.to_a(fractional: true).should be_close expected, 1e-15
    end

    it "fails for a non-periodic structure" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.pos.to_a fractional: true
      end
    end
  end

  describe "#to_cart!" do
    it "transforms fractional coordinates to Cartesian" do
      structure = Chem::Structure.build do
        cell 10, 20, 30
        atom Chem::PeriodicTable::O, vec3(0.2, 0.4, 0.6)
        atom Chem::PeriodicTable::H, vec3(0.1, 0.2, 0.3)
        atom Chem::PeriodicTable::H, vec3(0.6, 0.9, 0.35)
      end

      expected = [[2, 8, 18], [1, 4, 9], [6, 18, 10.5]]
      structure.pos.to_cart!.should be_close expected, 1e-15
    end
  end

  describe "#to_fract!" do
    it "transforms Cartesian coordinates to fractional" do
      structure = Chem::Structure.build do
        cell 10, 20, 30
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end

      expected = [[0.1, 0.1, 0.1], [0.4, 0.25, 0.2], [0.7, 0.4, 0.3]]
      structure.pos.to_fract!.should be_close expected, 1e-15
    end
  end

  describe "#unwrap" do
    it "unwraps a structure" do
      pos = load_file("5e61--wrapped.poscar", guess_bonds: true).pos
      pos.unwrap
      expected = load_file("5e61--unwrapped.poscar").pos
      pos.should be_close expected, 1e-3
    end

    it "unwraps a structure placing fragments close together" do
      pos = load_file("5e5v--wrapped.poscar", guess_bonds: true).pos
      pos.unwrap
      expected = load_file("5e5v--unwrapped.poscar").pos
      pos.should be_close expected, 1e-2
    end
  end

  describe "#wrap" do
    it "wraps atoms into the primary unit cell" do
      pos = load_file("AlaIle--unwrapped.poscar").pos
      pos.wrap
      expected = load_file("AlaIle--wrapped.poscar").pos
      pos.should be_close expected, 1e-15
    end

    it "wraps atoms into the primary unit cell in a non-rectangular cell" do
      pos = load_file("5e61--unwrapped.poscar").pos
      pos.wrap
      expected = load_file("5e61--wrapped.poscar").pos
      pos.should be_close expected, 1e-3
    end

    it "wraps atoms into the primary unit cell centered at the origin" do
      pos = load_file("5e61--unwrapped.poscar").pos
      pos.wrap around: vec3(0, 0, 0)
      expected = load_file("5e61--wrapped--origin.poscar").pos
      pos.should be_close expected, 1e-3
    end
  end
end
