require "./spec_helper"

describe Chem::AtomCollection do
  st = fake_structure

  describe "#atoms" do
    it "returns an atom view" do
      st.atoms.should be_a Chem::AtomView
    end
  end

  describe "#each_atom" do
    it "iterates over each atom when called with block" do
      ary = [] of Int32
      st.each_atom { |atom| ary << atom.serial }
      ary.should eq (1..25).to_a
    end

    it "returns an iterator when called without block" do
      st.each_atom.should be_a Iterator(Chem::Atom)
    end
  end

  describe "#n_atoms" do
    it "returns the number of atoms" do
      st.n_atoms.should eq 25
    end
  end
end

describe Chem::AtomView do
  atoms = fake_structure.atoms

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
  st = fake_structure
  glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]

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
    st = fake_structure
    glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    glu_cd.bonds.add glu_oe1, :double
    glu_cd.bonds.add glu_oe2

    it "returns the bond for a given atom" do
      glu_cd.bonds[glu_oe1].should be glu_cd.bonds[0]
    end

    it "fails when the bond does not exist" do
      expect_raises Chem::Error, "Atom 7 is not bonded to atom 6" do
        glu_cd.bonds[st.atoms[5]]
      end
    end
  end

  describe "#[]?" do
    st = fake_structure
    glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    glu_cd.bonds.add glu_oe1, :double
    glu_cd.bonds.add glu_oe2

    it "returns the bond for a given atom" do
      glu_cd.bonds[glu_oe1]?.should be glu_cd.bonds[0]
    end

    it "returns nil when the bond does not exist" do
      glu_cd.bonds[st.atoms[5]]?.should be_nil
    end
  end

  describe "#add" do
    it "adds a new bond" do
      st = fake_structure
      glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]

      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "doesn't add an existing bond" do
      st = fake_structure
      glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]

      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "doesn't add an existing bond (inversed)" do
      st = fake_structure
      glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]

      glu_cd.bonds.add glu_oe1, :double
      glu_oe1.bonds.add glu_cd
      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "fails when adding a bond that doesn't have the primary atom" do
      st = fake_structure
      glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]

      expect_raises Chem::Error, "Bond doesn't include atom 7" do
        glu_cd.bonds << Chem::Bond.new glu_oe1, glu_oe2
      end
    end

    # it "fails when adding a bond leads to an invalid valency" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double
    #   glu_cd.bonds.add glu_oe2

    #   expect_raises Chem::Error, "Atom 7 has only 1 valency electron available" do
    #     glu_cd.bonds.add st.atoms[5], :double
    #   end
    # end

    # it "fails when adding a bond leads to an invalid valency on secondary atom" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1

    #   expect_raises Chem::Error, "Atom 8 has only 1 valency electron available" do
    #     st.atoms[5].bonds.add glu_oe1, :double
    #   end
    # end

    # it "fails when the primary atom has its valency shell already full" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double

    #   expect_raises Chem::Error, "Atom 8 has its valency shell already full" do
    #     glu_oe1.bonds.add glu_oe2
    #   end
    # end

    # it "fails when the secondary atom has its valency shell already full" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double

    #   expect_raises Chem::Error, "Atom 8 has its valency shell already full" do
    #     glu_oe2.bonds.add glu_oe1
    #   end
    # end

    # it "fails when a charged atom has its valency shell already full" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe2
    #   glu_oe2.charge.should eq -1

    #   expect_raises Chem::Error, "Atom 9 has its valency shell already full" do
    #     glu_oe2.bonds.add st.atoms[5], :double
    #   end
    # end
  end

  describe "#delete" do
    it "deletes an existing bond" do
      st = fake_structure
      glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]

      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.add glu_oe2, :single

      glu_cd.bonds.delete glu_oe1
      glu_cd.bonds.size.should eq 1
      glu_oe1.bonds.size.should eq 0
    end

    it "doesn't delete a non-existing bond" do
      st = fake_structure
      glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]

      glu_cd.bonds.add glu_oe1, :double

      glu_cd.bonds.delete glu_oe2
      glu_cd.bonds.delete Chem::Bond.new(glu_cd, glu_oe2)
      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end
  end
end

describe Chem::ChainCollection do
  st = fake_structure

  describe "#chains" do
    it "returns a chain view" do
      st.chains.should be_a Chem::ChainView
    end
  end

  describe "#each_chain" do
    it "iterates over each chain when called with block" do
      ary = [] of Char?
      st.each_chain { |chain| ary << chain.id }
      ary.should eq ['A', 'B']
    end

    it "returns an iterator when called without block" do
      st.each_chain.should be_a Iterator(Chem::Chain)
    end
  end

  describe "#n_chains" do
    it "returns the number of chains" do
      st.n_chains.should eq 2
    end
  end
end

describe Chem::ChainView do
  chains = fake_structure.chains

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
  st = fake_structure

  describe "#each_residue" do
    it "iterates over each residue when called with block" do
      ary = [] of String
      st.each_residue { |residue| ary << residue.name }
      ary.should eq ["ASP", "PHE", "SER"]
    end

    it "returns an iterator when called without block" do
      st.each_residue.should be_a Iterator(Chem::Residue)
    end
  end

  describe "#n_residues" do
    it "returns the number of residues" do
      st.n_residues.should eq 3
    end
  end

  describe "#residues" do
    it "returns a residue view" do
      st.residues.should be_a Chem::ResidueView
    end
  end
end

describe Chem::ResidueView do
  residues = load_file("insertion_codes.pdb").residues

  describe "#[]" do
    it "gets residue by zero-based index" do
      residues[1].name.should eq "GLY"
    end

    it "gets residue by serial number" do
      residues[serial: 76].name.should eq "VAL"
    end

    it "gets residue by serial number (insertion codes)" do
      residue = residues[serial: 75]
      residue.number.should eq 75
      residue.insertion_code.should eq nil
      residue.name.should eq "TRP"
    end

    it "gets residue by serial number and insertion code" do
      residues = load_file("insertion_codes.pdb").residues
      residue = residues[75, 'B']
      residue.number.should eq 75
      residue.insertion_code.should eq 'B'
      residue.name.should eq "SER"
    end
  end

  describe "#size" do
    it "returns the number of residues" do
      residues.size.should eq 7
    end
  end
end
