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
      ref_pos = s[0].coords
      Chem::Spatial.rmsd(s[1].coords.align_to(ref_pos), ref_pos).should be_close 3.463298, 1e-6
      Chem::Spatial.rmsd(s[2].coords.align_to(ref_pos), ref_pos).should be_close 1.818679, 1e-6
      Chem::Spatial.rmsd(s[3].coords.align_to(ref_pos), ref_pos).should be_close 3.845655, 1e-6
      Chem::Spatial.rmsd(s[4].coords.align_to(ref_pos), ref_pos).should be_close 1.475276, 1e-6
    end
  end

  describe "#bounds" do
    it "returns the bounds" do
      bounds = structure.coords.bounds
      bounds.origin.should eq [1, 2, 3]
      bounds.size.should eq [6, 6, 6]
    end
  end

  describe "#center" do
    it "returns the geometric center" do
      structure.coords.center.should eq [4, 5, 6]
    end
  end

  describe "#center_along" do
    it "centers at the middle point of a vector" do
      structure.clone.coords.center_along(vec3(0, 0, 10)).center.should eq [4, 5, 5]
    end
  end

  describe "#center_at" do
    it "centers at the given vector" do
      structure.clone.coords.center_at(vec3(2.5, 3, 0)).center.should eq [2.5, 3, 0]
    end
  end

  describe "#center_at_cell" do
    it "centers at the primary unit cell" do
      structure.clone.coords.center_at_cell.center.should eq [5, 5, 5]
    end
  end

  describe "#center_at_origin" do
    it "centers at the origin" do
      structure.clone.coords.center_at_origin.center.should eq [0, 0, 0]
    end
  end

  describe "#com" do
    it "returns center of mass" do
      structure.coords.com.should be_close [1.5035248, 2.5035248, 3.5035248], 1e-6
    end
  end

  describe "#each" do
    it "yields the coordinates of every atom" do
      vecs = [] of Chem::Spatial::Vec3
      structure.coords.each { |coords| vecs << coords }
      vecs.should eq [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    end

    it "yields the fractional coordinates of every atom" do
      vecs = [] of Chem::Spatial::Vec3
      structure.coords.each(fractional: true) { |fcoords| vecs << fcoords }

      expected = [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6], [0.7, 0.8, 0.9]]
      vecs.should be_close expected, 1e-15
    end

    it "returns an iterator of coordinates" do
      structure.coords.each.to_a.should eq [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    end

    it "returns an iterator of fractional coordinates" do
      structure.coords.each(fractional: true).to_a.should be_close [
        [0.1, 0.2, 0.3], [0.4, 0.5, 0.6], [0.7, 0.8, 0.9],
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
      vecs = [] of Chem::Spatial::Vec3
      structure.coords.each_with_atom do |coords, atom|
        vecs << coords
        elements << atom.element.symbol
      end
      vecs.should eq [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      elements.should eq ["O", "H", "H"]
    end

    it "yields the fractional coordinates of every atom" do
      elements = [] of String
      vecs = [] of Chem::Spatial::Vec3
      structure.coords.each_with_atom(fractional: true) do |fcoords, atom|
        vecs << fcoords
        elements << atom.element.symbol
      end

      expected = [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6], [0.7, 0.8, 0.9]]
      vecs.should be_close expected, 1e-15
      elements.should eq ["O", "H", "H"]
    end

    it "fails for a non-periodic atom collection" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.coords.each(fractional: true) { }
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

      other.coords.map!(&.*(2)).should eq [[2, 4, 6], [8, 10, 12], [14, 16, 18]]
    end

    it "modifies the fractional atom coordinates" do
      other = Chem::Structure.build do
        cell 5, 10, 15
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end
      expected = [[6, 12, 18], [9, 15, 21], [12, 18, 24]]

      other.coords.map!(fractional: true, &.+(1)).should be_close expected, 1e-12
    end

    it "fails for a non-periodic atom collection" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.coords.map! fractional: true, &.itself
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

      other.coords.map_with_atom! { |vec, atom| vec * (atom.element.hydrogen? ? 1 : 3) }
      other.coords.should eq [[3, 6, 9], [4, 5, 6], [7, 8, 9]]
    end

    it "modifies the fractional atom coordinates" do
      other = Chem::Structure.build do
        cell 5, 10, 15
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end
      expected = [[6, 12, 18], [4, 5, 6], [7, 8, 9]]

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

  describe "#transform!" do
    it "transforms the atom coordinates" do
      other = Chem::Structure.build do
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end

      transform = Chem::Spatial::AffineTransform.translation vec3(-1, 0, 1)
      other.coords.transform!(transform).should eq [[0, 2, 4], [3, 5, 7], [6, 8, 10]]
    end

    it "rotates and translates atom coordinates" do
      other = Chem::Structure.build do
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end
      center = other.coords.center
      transform = Chem::Spatial::AffineTransform.euler(10, 50, 15).translate(vec3(1, 2, 3))
      expected = other.coords.to_a.map { |vec| transform * vec }
      other.coords.transform!(transform).should eq expected
    end

    it "aligns by a subset (#183)" do
      actual = Chem::Structure.from_pdb spec_file("pr183_actual.pdb")
      ref = Chem::Structure.from_pdb spec_file("pr183_ref.pdb")

      atoms, ref_atoms = {actual, ref}.map do |s|
        Chem::AtomView.new [52, 2, 12, 22, 32, 42].map { |i| s.atoms[i] }
      end
      tr = Chem::Spatial::AffineTransform.aligning(atoms, to: ref_atoms)
      actual.coords.transform! tr
      Chem::Spatial.rmsd(atoms.coords, ref_atoms.coords).should be_close 0.091, 1e-3
    end

    it "aligns to an axis (#183)" do
      sf = Chem::Structure.from_pdb spec_file("pr183_7M2I_sf-helice--aligned.pdb")
      ks = sf.atoms.select(&.potassium?)
      sf.coords.translate! -ks.mean(&.coords)

      # compute center of selected oxygens and set Y component to 0
      os = (75..78).map { |i| sf.chains.first.dig(i, "O") }
      oc = os.mean(&.coords).reject(Chem::Spatial::Vec3[0, 1, 0]).normalize
      transform = Chem::Spatial::AffineTransform.aligning oc, to: Chem::Spatial::Vec3[1, 0, 0]
      sf.coords.transform! transform
      os.mean(&.coords).should be_close Chem::Spatial::Vec3[2.348, 1.756, 0], 1e-3
    end
  end

  describe "#translate!" do
    it "translates the atom coordinates" do
      other = Chem::Structure.build do
        atom Chem::PeriodicTable::O, vec3(1, 2, 3)
        atom Chem::PeriodicTable::H, vec3(4, 5, 6)
        atom Chem::PeriodicTable::H, vec3(7, 8, 9)
      end

      expected = [[-2, 0, 2], [1, 3, 5], [4, 6, 8]]
      other.coords.translate!(by: vec3(-3, -2, -1)).should eq expected
    end
  end

  describe "#to_a" do
    it "returns the coordinates of the atoms" do
      structure.coords.to_a.should eq [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    end

    it "returns the fractional coordinates of the atoms" do
      expected = [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6], [0.7, 0.8, 0.9]]
      structure.coords.to_a(fractional: true).should be_close expected, 1e-15
    end

    it "fails for a non-periodic atom collection" do
      expect_raises Chem::Spatial::NotPeriodicError do
        fake_structure.coords.to_a fractional: true
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
      structure.coords.to_cart!.should be_close expected, 1e-15
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
      structure.coords.to_fract!.should be_close expected, 1e-15
    end
  end

  describe "#unwrap" do
    it "unwraps a structure" do
      coords = load_file("5e61--wrapped.poscar", guess_bonds: true).coords
      coords.unwrap
      expected = load_file("5e61--unwrapped.poscar").coords
      coords.should be_close expected, 1e-3
    end

    it "unwraps a structure placing fragments close together" do
      coords = load_file("5e5v--wrapped.poscar", guess_bonds: true).coords
      coords.unwrap
      expected = load_file("5e5v--unwrapped.poscar").coords
      coords.should be_close expected, 1e-2
    end
  end

  describe "#wrap" do
    it "wraps atoms into the primary unit cell" do
      coords = load_file("AlaIle--unwrapped.poscar").coords
      coords.wrap
      expected = load_file("AlaIle--wrapped.poscar").coords
      coords.should be_close expected, 1e-15
    end

    it "wraps atoms into the primary unit cell in a non-rectangular cell" do
      coords = load_file("5e61--unwrapped.poscar").coords
      coords.wrap
      expected = load_file("5e61--wrapped.poscar").coords
      coords.should be_close expected, 1e-3
    end

    it "wraps atoms into the primary unit cell centered at the origin" do
      coords = load_file("5e61--unwrapped.poscar").coords
      coords.wrap around: vec3(0, 0, 0)
      expected = load_file("5e61--wrapped--origin.poscar").coords
      coords.should be_close expected, 1e-3
    end
  end
end
