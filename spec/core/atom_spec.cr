require "../spec_helper"

describe Chem::Atom do
  describe "#<=>" do
    it "compares based on number" do
      atoms = load_file("5e5v.pdb").atoms
      (atoms[0] <=> atoms[1]).<(0).should be_true
      (atoms[1] <=> atoms[1]).should eq 0
      (atoms[2] <=> atoms[1]).>(0).should be_true
    end
  end

  describe "#bonded?" do
    it "tells if two atoms are bonded" do
      structure = Chem::Structure.build(guess_bonds: true) do
        atom :O, vec3(2.336, 3.448, 7.781)
        atom :H, vec3(1.446, 3.485, 7.315)
        atom :H, vec3(2.977, 2.940, 7.234)
      end
      structure.atoms[0].bonded?(structure.atoms[1]).should be_true
      structure.atoms[0].bonded?(structure.atoms[2]).should be_true
      structure.atoms[1].bonded?(structure.atoms[2]).should be_false
    end

    it "returns false when atom is itself" do
      structure = Chem::Structure.build(guess_bonds: true) do
        atom :O, vec3(2.336, 3.448, 7.781)
        atom :H, vec3(1.446, 3.485, 7.315)
        atom :H, vec3(2.977, 2.940, 7.234)
      end
      structure.atoms[0].bonded?(structure.atoms[0]).should be_false
      structure.atoms[1].bonded?(structure.atoms[1]).should be_false
      structure.atoms[2].bonded?(structure.atoms[2]).should be_false
    end
  end

  describe "#each_bonded_atom" do
    structure = Chem::Structure.build do
      atom :I, vec3(-1, 0, 0)
      atom :C, vec3(0, 0, 0)
      atom :N, vec3(1, 0, 0)
      bond "I1", "C1"
      bond "C1", "N1", :triple
    end

    it "yields bonded atoms" do
      ary = [] of Chem::Atom
      structure.atoms[1].each_bonded_atom { |atom| ary << atom }
      ary.map(&.name).should eq ["I1", "N1"]
    end

    it "returns an iterator of bonded atoms" do
      structure.atoms[1].each_bonded_atom.map(&.name).to_a.should eq ["I1", "N1"]
    end
  end

  describe "#het?" do
    it "tells if it belongs to a HET residue" do
      structure = load_file "1h1s.pdb"
      structure.dig('A', 56, "C").het?.should be_false    # protein
      structure.dig('A', 1298, "C10").het?.should be_true # ligand
      structure.dig('A', 2181, "O").het?.should be_true   # water
    end
  end

  describe "#matches?" do
    it "matches by template" do
      atom = Chem::Structure.build { atom "CD2", vec3(0, 0, 0) }.atoms[0]
      atom.should match Chem::Templates::Atom.new("CD2", "C")
      atom.should_not match Chem::Templates::Atom.new("CD2", "N")
      atom.should_not match Chem::Templates::Atom.new("ND2", "N")
    end

    it "matches by name" do
      struc = fake_structure
      struc.atoms[0].matches?("N").should be_true
      struc.atoms[0].matches?("CA").should be_false
      struc.atoms[0].matches?(/C[ABGD]?/).should be_false
      struc.atoms[1].matches?(/C[ABGD]?/).should be_true
      struc.atoms[0].matches?(%w(N CA C)).should be_true
      struc.atoms[3].matches?(%w(N CA C)).should be_false
    end

    it "matches by number" do
      struc = fake_structure
      struc.atoms[0].matches?(1).should be_true
      struc.atoms[0].matches?(2).should be_false
      struc.atoms[0].matches?([1, 3, 5, 7]).should be_true
      struc.atoms[0].matches?([2, 4, 6, 8]).should be_false
      struc.atoms[0].matches?(1..3).should be_true
      struc.atoms[-1].matches?(1..3).should be_false
    end
  end

  describe "#metadata" do
    it "returns the atom's metadata" do
      atom = fake_structure.dig('A', 1, "CA")
      atom.metadata.should be_empty
      atom.metadata["foo"] = Math::PI
      atom.metadata["foo"].should eq Math::PI
      atom.metadata.keys.should eq %w(foo)
    end
  end

  describe "#missing_valence" do
    it "returns number of bonds to reach closest target valence (no bonds)" do
      structure = Chem::Structure.build do
        atom :C, vec3(0, 0, 0)
      end
      structure.atoms[0].formal_charge = 0
      structure.atoms[0].missing_valence.should eq 4
    end

    it "returns number of bonds to reach closest target valence (bonds)" do
      structure = Chem::Structure.build do
        atom :C, vec3(0, 0, 0)
        atom :H, vec3(1, 0, 0)
        atom :H, vec3(-1, 0, 0)
        bond "C1", "H1"
        bond "C1", "H2"
      end
      structure.atoms[0].missing_valence.should eq 2
    end

    it "returns number of bonds to reach closest target valence (full bonds)" do
      structure = Chem::Structure.build do
        atom :C, vec3(0, 0, 0)
        atom :O, vec3(0, 1, 0)
        atom :C, vec3(-1, 0, 0)
        atom :C, vec3(1, 0, 0)
        bond "C1", "O1", :double
        bond "C1", "C2"
        bond "C1", "C3"
      end
      structure.atoms[0].missing_valence.should eq 0
    end

    it "returns number of bonds to reach closest target valence (over bonds)" do
      structure = Chem::Structure.build do
        atom :N, vec3(0, 0, 0)
        atom :C, vec3(-1, 0, 0)
        atom :H, vec3(1, 0, 0)
        atom :H, vec3(0, 1, 0)
        atom :H, vec3(0, -1, 0)
        bond "C1", "N1"
        bond "N1", "H1"
        bond "N1", "H2"
        bond "N1", "H3"
      end
      structure.atoms[0].missing_valence.should eq 0
    end
  end

  describe "#spec" do
    it "returns the atom specification" do
      fake_structure.dig('A', 1, "CA").spec.should eq "A:ASP1:CA(2)"
    end

    it "writes the atom specification" do
      io = IO::Memory.new
      fake_structure.dig('B', 1, "OG").spec io
      io.to_s.should eq "B:SER1:OG(25)"
    end
  end

  describe "#target_valence" do
    it "returns target valence (no bonds)" do
      structure = Chem::Structure.build do
        atom :C, vec3(0, 0, 0)
      end
      structure.atoms[0].target_valence.should eq 4
    end

    it "returns target valence (bonds)" do
      structure = Chem::Structure.build do
        atom :I, vec3(-1, 0, 0)
        atom :C, vec3(0, 0, 0)
        atom :N, vec3(1, 0, 0)
        bond "I1", "C1"
        bond "C1", "N1", :triple
      end
      structure.atoms.map(&.target_valence).should eq [1, 4, 3]
    end

    it "returns target valence (bonds exceed maximum valence)" do
      structure = Chem::Structure.build do
        atom :N, vec3(1, 0, 0)
        atom :H, vec3(-1, 0, 0)
        atom :H, vec3(1, 0, 0)
        atom :H, vec3(0, 1, 0)
        atom :H, vec3(0, -1, 0)
        bond "N1", "H1"
        bond "N1", "H2"
        bond "N1", "H3"
        bond "N1", "H4"
      end
      structure.atoms[0].target_valence.should eq 3
    end

    it "returns target valence (multiple valencies, 1)" do
      structure = Chem::Structure.build do
        atom :C, vec3(-1, 0, 0)
        atom :S, vec3(0, 0, 0)
        atom :H, vec3(1, 0, 0)
        bond "C1", "S1", :triple
        bond "S1", "H1"
      end
      structure.atoms[1].target_valence.should eq 4
    end

    it "returns target valence (multiple valencies, 2)" do
      structure = Chem::Structure.build do
        atom :O, vec3(-1, 0, 0)
        atom :S, vec3(0, 0, 0)
        atom :O, vec3(1, 0, 0)
        atom :O, vec3(0, 1, 0)
        atom :O, vec3(0, -1, 0)
        bond "O1", "S1"
        bond "S1", "O2"
        bond "S1", "O3", :double
        bond "S1", "O4", :double
      end
      structure.atoms[1].target_valence.should eq 6
    end

    it "returns target valence (multiple valencies, 3)" do
      structure = Chem::Structure.build do
        atom :O, vec3(-1, 0, 0)
        atom :S, vec3(0, 0, 0)
        atom :O, vec3(1, 0, 0)
        atom :O, vec3(0, 1, 0)
        atom :O, vec3(0, -1, 0)
        atom :O, vec3(1, -1, 0)
        bond "O1", "S1"
        bond "S1", "O2"
        bond "S1", "O3", :double
        bond "S1", "O4", :double
        bond "S1", "O5"
      end
      structure.atoms[1].target_valence.should eq 6
    end

    it "returns maximum valence for ionic elements" do
      structure = Chem::Structure.build do
        atom :Na, vec3(0, 0, 0)
      end
      structure.atoms[0].target_valence.should eq 1
    end
  end

  describe "#within_covalent_distance?" do
    res = fake_structure.residues[0]

    it "returns true for covalently-bonded atoms" do
      res["N"].within_covalent_distance?(res["CA"]).should be_true
      res["CA"].within_covalent_distance?(res["C"]).should be_true
      res["CB"].within_covalent_distance?(res["CA"]).should be_true
    end

    it "returns false for non-bonded atoms" do
      res["N"].within_covalent_distance?(res["CB"]).should be_false
      res["CA"].within_covalent_distance?(res["O"]).should be_false
      res["CA"].within_covalent_distance?(res["OD1"]).should be_false
    end
  end

  describe "#water?" do
    it "tells if it belongs to a water residue" do
      structure = load_file "1h1s.pdb"
      structure.dig('A', 56, "C").water?.should be_false     # protein
      structure.dig('A', 1298, "C10").water?.should be_false # ligand
      structure.dig('A', 2181, "O").water?.should be_true    # water
    end
  end
end
