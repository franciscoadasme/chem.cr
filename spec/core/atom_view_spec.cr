require "../spec_helper"

describe Chem::AtomView do
  # TODO: remove this global
  atoms = fake_structure.atoms

  describe "#[]" do
    it "gets atom by zero-based index" do
      atoms[4].name.should eq "CB"
    end
  end

  describe "#chains" do
    it "returns the chains" do
      atoms.chains.map(&.id).should eq ['A', 'B']
    end
  end

  describe "#fragments" do
    it "returns the fragments (1)" do
      struc = Chem::Structure.read spec_file("5e61--unwrapped.poscar")
      struc.guess_bonds
      struc.atoms.fragments.map(&.size).should eq [100, 100]
    end

    it "returns the fragments (2)" do
      struc = Chem::Structure.read spec_file("5e61--unwrapped.poscar")
      struc.guess_bonds
      struc.atoms.fragments.map(&.size).should eq [100, 100]
    end

    it "returns the fragments (3)" do
      struc = Chem::Structure.read spec_file("k2p_pore_b.xyz")
      struc.guess_bonds
      struc.atoms.fragments.map(&.size).sort!.should eq [1, 1, 1, 1, 304, 334]
    end

    it "returns fragments limited to the selected atoms " do
      struc = Chem::Structure.read spec_file("5e5v.pdb")
      struc.guess_bonds
      struc.atoms[0..205].fragments.map(&.size).should eq [103, 103]
      struc.atoms[0..150].fragments.map(&.size).should eq [103, 48]
      struc.atoms[0..50].fragments.map(&.size).should eq [51]
      struc.atoms[0..0].fragments.map(&.size).should eq [1]

      ary = struc.atoms[0..10].to_a
      ary.concat struc.atoms[150..158] # => O=C(i)-N(i+1)-H-CA, sidechain(i) (no CA(i)-CB)
      ary.concat struc.atoms[210..220] # => H1, H2, HOH, HOH, HOH
      Chem::AtomView.new(ary).fragments.map(&.size).should eq [11, 5, 4, 1, 1, 3, 3, 3]
    end
  end

  describe "#residues" do
    it "return the residues" do
      residues = atoms.residues
      residues.map(&.name).should eq %w(ASP PHE SER)
      residues.map(&.number).should eq [1, 2, 1]
    end
  end

  describe "#size" do
    it "returns the number of chains" do
      atoms.size.should eq 25
    end
  end

  describe "#to_a" do
    it "returns a copy of the enclosed array" do
      struc = fake_structure
      ary = struc.atoms.to_a
      ary.should eq struc.atoms.to_unsafe
      ary.same?(struc.atoms.to_unsafe).should be_false
      size = struc.atoms.size
      ary.clear
      struc.atoms.size.should eq size
    end
  end

  describe "#to_unsafe" do
    it "returns the enclosed array" do
      struc = fake_structure
      inner = struc.atoms.to_unsafe
      struc.atoms.to_unsafe.same?(inner).should be_true
      struc.atoms.to_unsafe.size.should eq struc.atoms.size
    end
  end

  describe "#sort_by_symmetry" do
    it "permutes symmetric atoms to match a reference" do
      ref, mobile = phe_pair_with_flipped_ring
      ordered = mobile.atoms.sort_by_symmetry(to: ref.atoms)
      ordered.zip(ref.atoms) { |a, b| a.pos.should eq b.pos }
      # the structure itself is unchanged; only the returned view is permuted
      phe = mobile.residues.find!(&.name.==("PHE"))
      phe["CD1"].pos.should_not eq ref.residues.find!(&.name.==("PHE"))["CD1"].pos
    end

    it "does not mutate the original view" do
      ref, mobile = phe_pair_with_flipped_ring
      original = mobile.atoms.to_a
      mobile.atoms.sort_by_symmetry(to: ref.atoms)
      mobile.atoms.to_a.should eq original
    end

    it "raises if the two views have different sizes" do
      s = fake_structure
      expect_raises(ArgumentError, "Incompatible coordinates") do
        s.atoms[0..2].sort_by_symmetry(to: s.atoms[0..4])
      end
    end

    it "leaves atoms unchanged when there are no symmetric atoms" do
      ref = fake_structure
      mobile = ref.clone
      ser_ref = ref.residues.find!(&.name.==("SER")).atoms
      ser_mobile = mobile.residues.find!(&.name.==("SER")).atoms
      ordered = ser_mobile.sort_by_symmetry(to: ser_ref)
      ordered.zip(ser_mobile) { |a, b| a.should be b }
    end

    it "leaves atoms unchanged when they have no residue topology" do
      ref = Chem::Structure.build do
        atom Chem::PeriodicTable::C, vec3(0, 0, 0)
        atom Chem::PeriodicTable::C, vec3(1, 0, 0)
      end
      mobile = Chem::Structure.build do
        atom Chem::PeriodicTable::C, vec3(1, 0, 0)
        atom Chem::PeriodicTable::C, vec3(0, 0, 0)
      end
      ordered = mobile.atoms.sort_by_symmetry(to: ref.atoms)
      ordered.zip(mobile.atoms) { |a, b| a.should be b }
    end

    it "permutes independent groups on different residues" do
      ref = fake_structure
      mobile = ref.clone
      asp = mobile.residues.find!(&.name.==("ASP"))
      phe = mobile.residues.find!(&.name.==("PHE"))
      swap_named_positions asp, {"OD1" => "OD2"}
      swap_named_positions phe, {"CD1" => "CD2", "CE1" => "CE2"}

      ordered = mobile.atoms.sort_by_symmetry(to: ref.atoms)
      ordered.zip(ref.atoms) { |a, b| a.pos.should eq b.pos }
      ordered[index_of(ref.atoms, "ASP", "OD1")].name.should eq "OD2"
      ordered[index_of(ref.atoms, "PHE", "CD1")].name.should eq "CD2"
    end

    it "permutes a partial residue when the full group is present" do
      ref, mobile = phe_pair_with_flipped_ring
      names = %w(CD1 CD2 CE1 CE2)
      ref_sel = ref.dig('A', 2).atoms.select(names)
      mobile_sel = mobile.dig('A', 2).atoms.select(names)
      ordered = mobile_sel.sort_by_symmetry(to: ref_sel)
      ordered.zip(ref_sel) { |a, b| a.pos.should eq b.pos }
      ordered[0].name.should eq "CD2"
    end

    it "skips a group when a pair is incomplete" do
      ref, mobile = phe_pair_with_flipped_ring
      names = %w(N CA C CB CG CD1 CE1 CZ)
      ref_sel = ref.dig('A', 2).atoms.select(names)
      mobile_sel = mobile.dig('A', 2).atoms.select(names)
      ordered = mobile_sel.sort_by_symmetry(to: ref_sel)
      ordered.zip(mobile_sel) { |a, b| a.should be b }
    end

    it "permutes hydrogens together with their heavy atoms" do
      ref = Chem::Structure.from_pdb spec_file("5e5v.pdb")
      mobile = ref.clone
      phe_pairs = {"CD1" => "CD2", "CE1" => "CE2", "HD1" => "HD2", "HE1" => "HE2"}
      leu_pairs = {"CD1" => "CD2", "HD11" => "HD21", "HD12" => "HD22", "HD13" => "HD23"}
      swap_named_positions mobile.dig('A', 2), phe_pairs
      swap_named_positions mobile.dig('A', 6), leu_pairs

      ordered = mobile.atoms.sort_by_symmetry(to: ref.atoms)
      ordered.zip(ref.atoms) { |a, b| a.pos.should eq b.pos }
      ordered[index_of(ref.atoms, "PHE", "HD1")].name.should eq "HD2"
      ordered[index_of(ref.atoms, "LEU", "HD11")].name.should eq "HD21"
    end

    it "resolves a rotated ring flip when non-symmetric anchors are present" do
      ref, mobile = phe_pair_with_flipped_ring
      mobile.pos.rotate(40, 75, 20)
      ordered = mobile.atoms.sort_by_symmetry(to: ref.atoms)
      # backbone atoms pin the local superposition, so CD1's slot gets CD2
      ordered[index_of(ref.atoms, "PHE", "CD1")].name.should eq "CD2"
      ordered[index_of(ref.atoms, "PHE", "CE1")].name.should eq "CE2"
    end

    it "cannot distinguish a rotated ring flip from a regular hexagon without anchors" do
      ref, mobile = regular_hexagon_with_flipped_ring
      mobile.pos.rotate(35, 80, 15)
      names = %w(C2 C3 C4 C5 C6)
      ref_sel = Chem::AtomView.new names.map { |name| ref.residues[0][name] }
      mobile_sel = Chem::AtomView.new names.map { |name| mobile.residues[0][name] }
      ordered = mobile_sel.sort_by_symmetry(to: ref_sel)
      # Without off-axis anchors, QCP fit RMSD is ~0 for both assignments
      # because superposition absorbs the 180° ring rotation. The current
      # approach then ranks by in-place RMSD, which still prefers the
      # cartesian-closer (flipped) pairing even though that score is not
      # a superposition match.
      ordered.map(&.name).should eq %w(C6 C5 C4 C3 C2)
    end

    it "uses an off-axis anchor to resolve a rotated hexagon flip" do
      ref, mobile = regular_hexagon_with_flipped_ring
      mobile.pos.rotate(35, 80, 15)
      ordered = mobile.atoms.sort_by_symmetry(to: ref.atoms)
      ordered[index_of(ref.atoms, "HX6", "C2")].name.should eq "C6"
      ordered[index_of(ref.atoms, "HX6", "C3")].name.should eq "C5"
    end
  end
end

private def phe_pair_with_flipped_ring : {Chem::Structure, Chem::Structure}
  ref = fake_structure
  mobile = ref.clone
  swap_named_positions mobile.residues.find!(&.name.==("PHE")), {"CD1" => "CD2", "CE1" => "CE2"}
  {ref, mobile}
end

private def swap_named_positions(residue : Chem::Residue, pairs : Hash(String, String)) : Nil
  pairs.each do |a, b|
    residue[a].pos, residue[b].pos = residue[b].pos, residue[a].pos
  end
end

private def index_of(atoms : Chem::AtomView, residue_name : String, atom_name : String) : Int32
  atoms.index! { |atom| atom.residue.name == residue_name && atom.name == atom_name }
end

private def regular_hexagon_with_flipped_ring : {Chem::Structure, Chem::Structure}
  unless Chem::Templates::Registry.default["HX6"]?
    Chem::Templates::Registry.default.register do
      name "HX6"
      spec "C0-C1%1=C2-C3=C4-C5=C6-%1"
      symmetry({"C2", "C6"}, {"C3", "C5"})
    end
  end

  s3 = Math.sqrt(3) / 2
  ref = Chem::Structure.build do
    residue "HX6" do
      atom "C0", vec3(2, 0, 0)
      atom "C1", vec3(1, 0, 0)
      atom "C2", vec3(0.5, s3, 0)
      atom "C3", vec3(-0.5, s3, 0)
      atom "C4", vec3(-1, 0, 0)
      atom "C5", vec3(-0.5, -s3, 0)
      atom "C6", vec3(0.5, -s3, 0)
    end
  end
  mobile = ref.clone
  swap_named_positions mobile.residues[0], {"C2" => "C6", "C3" => "C5"}
  {ref, mobile}
end
