require "./spec_helper"

describe Chem::AtomCollection do
  system = fake_system

  describe "#atoms" do
    it "returns an atom view" do
      system.atoms.should be_a Chem::AtomView
    end
  end

  describe "#each_atom" do
    it "iterates over each atom when called with block" do
      ary = [] of Int32
      system.each_atom { |atom| ary << atom.serial }
      ary.should eq (1..25).to_a
    end

    it "returns an iterator when called without block" do
      system.each_atom.should be_a Iterator(Chem::Atom)
    end
  end
end

describe Chem::AtomView do
  atoms = fake_system.atoms

  describe "#[]" do
    it "gets atom by zero-based index" do
      atoms[4].name.should eq "CB"
    end

    it "gets atom by serial number" do
      atoms[serial: 5].name.should eq "CB"
    end
  end

  describe "#size" do
    it "returns the number of chains" do
      atoms.size.should eq 25
    end
  end
end

describe Chem::Bond do
  system = fake_system
  glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]

  describe "#==" do
    it "returns true when the atoms are in the same order" do
      Chem::Bond.new(glu_cd, glu_oe1).should eq Chem::Bond.new(glu_cd, glu_oe1)
    end

    it "returns true when the atoms are in the inverse order" do
      Chem::Bond.new(glu_cd, glu_oe1).should eq Chem::Bond.new(glu_oe1, glu_cd)
    end

    it "returns true when the atoms are the same but the bond orders are different" do
      Chem::Bond.new(glu_cd, glu_oe1).should eq Chem::Bond.new(glu_cd, glu_oe1, :double)
    end

    it "returns false when the atoms are not the same" do
      Chem::Bond.new(glu_cd, glu_oe1).should_not eq Chem::Bond.new(glu_cd, glu_oe2)
    end
  end

  describe "#includes?" do
    it "returns true when the bond includes the given atom" do
      Chem::Bond.new(glu_cd, glu_oe1).includes?(glu_cd).should be_true
      Chem::Bond.new(glu_cd, glu_oe1).includes?(glu_oe1).should be_true
    end

    it "returns false when the bond does not include the given atom" do
      Chem::Bond.new(glu_cd, glu_oe1).includes?(glu_oe2).should be_false
    end
  end

  describe "#order" do
    it "returns order as a number" do
      Chem::Bond.new(glu_cd, glu_oe1).order.should eq 1
      Chem::Bond.new(glu_cd, glu_oe1, :zero).order.should eq 0
      Chem::Bond.new(glu_cd, glu_oe1, :double).order.should eq 2
      Chem::Bond.new(glu_cd, glu_oe1, :triple).order.should eq 3
      Chem::Bond.new(glu_cd, glu_oe1, :dative).order.should eq 1
    end
  end

  describe "#order=" do
    bond = Chem::Bond.new glu_cd, glu_oe1

    it "changes bond order" do
      bond.kind.should eq Chem::Bond::Kind::Single
      bond.order.should eq 1

      bond.order = 2
      bond.kind.should eq Chem::Bond::Kind::Double
      bond.order.should eq 2

      bond.order = 3
      bond.kind.should eq Chem::Bond::Kind::Triple
      bond.order.should eq 3

      bond.order = 0
      bond.kind.should eq Chem::Bond::Kind::Zero
      bond.order.should eq 0
    end

    it "fails when order is invalid" do
      expect_raises Chem::Error, "Bond order (5) is invalid" do
        bond.order = 5
      end
    end
  end

  describe "#other" do
    it "returns the other atom" do
      bond = Chem::Bond.new glu_cd, glu_oe1
      bond.other(glu_cd).should be glu_oe1
      bond.other(glu_oe1).should be glu_cd
    end

    it "fails when the bond does not include the given atom" do
      expect_raises Chem::Error, "Bond doesn't include atom 9" do
        Chem::Bond.new(glu_cd, glu_oe1).other glu_oe2
      end
    end
  end
end

describe Chem::BondArray do
  describe "#[]" do
    system = fake_system
    glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]
    glu_cd.bonds.add glu_oe1, :double
    glu_cd.bonds.add glu_oe2

    it "returns the bond for a given atom" do
      glu_cd.bonds[glu_oe1].should be glu_cd.bonds[0]
    end

    it "fails when the bond does not exist" do
      expect_raises Chem::Error, "Atom 7 is not bonded to atom 6" do
        glu_cd.bonds[system.atoms[5]]
      end
    end
  end

  describe "#[]?" do
    system = fake_system
    glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]
    glu_cd.bonds.add glu_oe1, :double
    glu_cd.bonds.add glu_oe2

    it "returns the bond for a given atom" do
      glu_cd.bonds[glu_oe1]?.should be glu_cd.bonds[0]
    end

    it "returns nil when the bond does not exist" do
      glu_cd.bonds[system.atoms[5]]?.should be_nil
    end
  end

  describe "#add" do
    it "adds a new bond" do
      system = fake_system
      glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]

      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "doesn't add an existing bond" do
      system = fake_system
      glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]

      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "doesn't add an existing bond (inversed)" do
      system = fake_system
      glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]

      glu_cd.bonds.add glu_oe1, :double
      glu_oe1.bonds.add glu_cd
      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "fails when adding a bond that doesn't have the primary atom" do
      system = fake_system
      glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]

      expect_raises Chem::Error, "Bond doesn't include atom 7" do
        glu_cd.bonds << Chem::Bond.new glu_oe1, glu_oe2
      end
    end

    # it "fails when adding a bond leads to an invalid valence" do
    #   system = fake_system
    #   glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double
    #   glu_cd.bonds.add glu_oe2

    #   expect_raises Chem::Error, "Atom 7 has only 1 valence electron available" do
    #     glu_cd.bonds.add system.atoms[5], :double
    #   end
    # end

    # it "fails when adding a bond leads to an invalid valence on secondary atom" do
    #   system = fake_system
    #   glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1

    #   expect_raises Chem::Error, "Atom 8 has only 1 valence electron available" do
    #     system.atoms[5].bonds.add glu_oe1, :double
    #   end
    # end

    # it "fails when the primary atom has its valence shell already full" do
    #   system = fake_system
    #   glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double

    #   expect_raises Chem::Error, "Atom 8 has its valence shell already full" do
    #     glu_oe1.bonds.add glu_oe2
    #   end
    # end

    # it "fails when the secondary atom has its valence shell already full" do
    #   system = fake_system
    #   glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double

    #   expect_raises Chem::Error, "Atom 8 has its valence shell already full" do
    #     glu_oe2.bonds.add glu_oe1
    #   end
    # end

    # it "fails when a charged atom has its valence shell already full" do
    #   system = fake_system
    #   glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]
    #   glu_cd.bonds.add glu_oe2
    #   glu_oe2.charge.should eq -1

    #   expect_raises Chem::Error, "Atom 9 has its valence shell already full" do
    #     glu_oe2.bonds.add system.atoms[5], :double
    #   end
    # end
  end

  describe "#delete" do
    it "deletes an existing bond" do
      system = fake_system
      glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]

      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.add glu_oe2, :single

      glu_cd.bonds.delete glu_oe1
      glu_cd.bonds.size.should eq 1
      glu_oe1.bonds.size.should eq 0
    end

    it "doesn't delete a non-existing bond" do
      system = fake_system
      glu_cd, glu_oe1, glu_oe2 = system.atoms[6..8]

      glu_cd.bonds.add glu_oe1, :double

      glu_cd.bonds.delete glu_oe2
      glu_cd.bonds.delete Chem::Bond.new(glu_cd, glu_oe2)
      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end
  end
end

describe Chem::ChainCollection do
  system = fake_system

  describe "#chains" do
    it "returns a chain view" do
      system.chains.should be_a Chem::ChainView
    end
  end

  describe "#each_chain" do
    it "iterates over each chain when called with block" do
      ary = [] of Char?
      system.each_chain { |chain| ary << chain.id }
      ary.should eq ['A', 'B']
    end

    it "returns an iterator when called without block" do
      system.each_chain.should be_a Iterator(Chem::Chain)
    end
  end
end

describe Chem::ChainView do
  chains = fake_system.chains

  describe "#[]" do
    it "gets chain by zero-based index" do
      chains[0].id.should eq 'A'
    end

    it "gets chain by identifier" do
      chains['A'].id.should eq 'A'
    end
  end

  describe "#size" do
    it "returns the number of chains" do
      chains.size.should eq 2
    end
  end
end

describe Chem::ResidueCollection do
  system = fake_system

  describe "#each_residue" do
    it "iterates over each residue when called with block" do
      ary = [] of String
      system.each_residue { |residue| ary << residue.name }
      ary.should eq ["ASP", "PHE", "SER"]
    end

    it "returns an iterator when called without block" do
      system.each_residue.should be_a Iterator(Chem::Residue)
    end
  end

  describe "#residues" do
    it "returns a residue view" do
      system.residues.should be_a Chem::ResidueView
    end
  end
end

describe Chem::ResidueView do
  residues = fake_system.residues

  describe "#[]" do
    it "gets residue by zero-based index" do
      residues[1].name.should eq "PHE"
    end

    it "gets residue by serial number" do
      residues[serial: 2].name.should eq "PHE"
    end
  end

  describe "#size" do
    it "returns the number of residues" do
      residues.size.should eq 3
    end
  end
end

describe Chem::System do
  system = fake_system

  describe "#size" do
    it "returns the number of atoms" do
      system.size.should eq 25
    end
  end
end

describe Chem::Topology do
  describe "#guess_topology" do
    it "works" do
      system = fake_system
      r1, r2, r3 = system.residues

      Chem::Topology.guess_topology system

      [r1, r2, r3].map(&.protein?).should eq [true, true, true]
      [r1, r2, r3].map(&.formal_charge).should eq [-1, 0, 0]

      r1.atoms["N"].bonded_atoms.map(&.name).should eq ["CA"]

      r1.atoms["N"].bonds[r1.atoms["CA"]].order.should eq 1
      r1.atoms["CA"].bonds[r1.atoms["C"]].order.should eq 1
      r1.atoms["C"].bonds[r1.atoms["O"]].order.should eq 2
      r1.atoms["CA"].bonds[r1.atoms["CB"]].order.should eq 1
      r1.atoms["CB"].bonds[r1.atoms["CG"]].order.should eq 1
      r1.atoms["CG"].bonds[r1.atoms["OD1"]].order.should eq 2
      r1.atoms["CG"].bonds[r1.atoms["OD2"]].order.should eq 1

      r1.atoms["C"].bonded_atoms.map(&.name).should eq ["CA", "O", "N"]
      r2.atoms["N"].bonded_atoms.map(&.name).should eq ["C", "CA"]

      r2.atoms["N"].bonds[r2.atoms["CA"]].order.should eq 1
      r2.atoms["CA"].bonds[r2.atoms["C"]].order.should eq 1
      r2.atoms["C"].bonds[r2.atoms["O"]].order.should eq 2
      r2.atoms["CA"].bonds[r2.atoms["CB"]].order.should eq 1
      r2.atoms["CB"].bonds[r2.atoms["CG"]].order.should eq 1
      r2.atoms["CG"].bonds[r2.atoms["CD1"]].order.should eq 2
      r2.atoms["CD1"].bonds[r2.atoms["CE1"]].order.should eq 1
      r2.atoms["CE1"].bonds[r2.atoms["CZ"]].order.should eq 2
      r2.atoms["CZ"].bonds[r2.atoms["CE2"]].order.should eq 1
      r2.atoms["CE2"].bonds[r2.atoms["CD2"]].order.should eq 2
      r2.atoms["CD2"].bonds[r2.atoms["CG"]].order.should eq 1

      r2.atoms["C"].bonded_atoms.map(&.name).should eq ["CA", "O"]
      r3.atoms["N"].bonded_atoms.map(&.name).should eq ["CA"]

      r3.atoms["N"].bonds[r3.atoms["CA"]].order.should eq 1
      r3.atoms["CA"].bonds[r3.atoms["C"]].order.should eq 1
      r3.atoms["C"].bonds[r3.atoms["O"]].order.should eq 2
      r3.atoms["CA"].bonds[r3.atoms["CB"]].order.should eq 1
      r3.atoms["CB"].bonds[r3.atoms["OG"]].order.should eq 1

      r3.atoms["C"].bonded_atoms.map(&.name).should eq ["CA", "O"]
    end

    it "does not connect consecutive residues when there are far away" do
      system = PDB.parse "spec/data/pdb/protein_gap.pdb"
      r1, r2, r3, r4 = system.residues

      Chem::Topology.guess_topology system

      r1["C"].bonds[r2["N"]]?.should_not be_nil
      r2["C"].bonds[r3["N"]]?.should be_nil
      r3["C"].bonds[r4["N"]]?.should_not be_nil
    end

    it "guess kind of unknown residue when previous is known" do
      system = PDB.parse "spec/data/pdb/residue_kind_unknown_previous.pdb"
      Chem::Topology.guess_topology system
      system.residues[1].protein?.should be_true
    end

    it "guess kind of unknown residue when next is known" do
      system = PDB.parse "spec/data/pdb/residue_kind_unknown_next.pdb"
      Chem::Topology.guess_topology system
      system.residues[0].protein?.should be_true
    end

    it "guess kind of unknown residue when its flanked by known residues" do
      system = PDB.parse "spec/data/pdb/residue_kind_unknown_flanked.pdb"
      Chem::Topology.guess_topology system
      system.residues[1].protein?.should be_true
    end

    it "does not guess kind of unknown residue" do
      system = PDB.parse "spec/data/pdb/residue_kind_unknown_single.pdb"
      Chem::Topology.guess_topology system
      system.residues[0].other?.should be_true
    end

    it "does not guess kind of unknown residue when its not connected to others" do
      system = PDB.parse "spec/data/pdb/residue_kind_unknown_next_gap.pdb"
      Chem::Topology.guess_topology system
      system.residues.first.other?.should be_true
    end
  end
end
