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

describe Chem::BondArray do
  describe "#[]" do
    st = fake_structure
    glu_cd = st.dig('A', 1, "CG")
    glu_oe1 = st.dig('A', 1, "OD1")
    glu_oe2 = st.dig('A', 1, "OD2")

    it "returns the bond for a given atom" do
      bond = glu_cd.bonds[glu_oe1]
      bond.other(glu_cd).should eq glu_oe1
    end

    it "fails when the bond does not exist" do
      expect_raises Chem::Error, "Atom 6 is not bonded to atom 9" do
        glu_cd.bonds[st.dig('A', 2, "N")]
      end
    end
  end

  describe "#[]?" do
    st = fake_structure
    glu_cd = st.dig('A', 1, "CG")
    glu_oe1 = st.dig('A', 1, "OD1")
    glu_oe2 = st.dig('A', 1, "OD2")

    it "returns the bond for a given atom" do
      bond = glu_cd.bonds[glu_oe1]
      bond.other(glu_cd).should eq glu_oe1
    end

    it "returns nil when the bond does not exist" do
      glu_cd.bonds[st.dig('A', 2, "N")]?.should be_nil
    end
  end

  describe "#add" do
    it "adds a new bond" do
      st = fake_structure include_bonds: false
      glu_cd = st.dig('A', 1, "CG")
      glu_oe1 = st.dig('A', 1, "OD1")
      glu_oe2 = st.dig('A', 1, "OD2")

      st.each_atom do |atom|
        atom.bonded_atoms.each do |other|
          atom.bonds.delete other
        end
      end
      glu_cd.bonds.add glu_oe1, :double

      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "doesn't add an existing bond" do
      st = fake_structure include_bonds: false
      glu_cd = st.dig('A', 1, "CG")
      glu_oe1 = st.dig('A', 1, "OD1")
      glu_oe2 = st.dig('A', 1, "OD2")

      st.each_atom do |atom|
        atom.bonded_atoms.each do |other|
          atom.bonds.delete other
        end
      end
      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.add glu_oe1, :double

      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "doesn't add an existing bond (inversed)" do
      st = fake_structure include_bonds: false
      glu_cd = st.dig('A', 1, "CG")
      glu_oe1 = st.dig('A', 1, "OD1")
      glu_oe2 = st.dig('A', 1, "OD2")

      st.each_atom do |atom|
        atom.bonded_atoms.each do |other|
          atom.bonds.delete other
        end
      end
      glu_cd.bonds.add glu_oe1, :double
      glu_oe1.bonds.add glu_cd

      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "fails when adding a bond that doesn't have the primary atom" do
      st = fake_structure include_bonds: false
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
      st = fake_structure include_bonds: false
      glu_cd = st.dig('A', 1, "CG")
      glu_oe1 = st.dig('A', 1, "OD1")
      glu_oe2 = st.dig('A', 1, "OD2")

      st.each_atom do |atom|
        atom.bonded_atoms.each do |other|
          atom.bonds.delete other
        end
      end
      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.add glu_oe2, :single

      glu_cd.bonds.delete glu_oe1
      glu_cd.bonds.size.should eq 1
      glu_oe1.bonds.size.should eq 0
    end

    it "doesn't delete a non-existing bond" do
      st = fake_structure include_bonds: false
      glu_cd = st.dig('A', 1, "CG")
      glu_oe1 = st.dig('A', 1, "OD1")
      glu_oe2 = st.dig('A', 1, "OD2")

      st.each_atom do |atom|
        atom.bonded_atoms.each do |other|
          atom.bonds.delete other
        end
      end
      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.delete glu_oe2
      glu_cd.bonds.delete Chem::Bond.new(glu_cd, glu_oe2)

      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end
  end
end

describe Chem::ChainCollection do
  st = fake_structure include_bonds: false

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
