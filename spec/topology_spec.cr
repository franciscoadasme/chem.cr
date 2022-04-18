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

      glu_cd.bonds.add glu_oe1, :double

      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "doesn't add an existing bond" do
      st = fake_structure include_bonds: false
      glu_cd = st.dig('A', 1, "CG")
      glu_oe1 = st.dig('A', 1, "OD1")
      glu_oe2 = st.dig('A', 1, "OD2")

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

    # it "fails when adding a bond leads to an invalid valence" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double
    #   glu_cd.bonds.add glu_oe2

    #   expect_raises Chem::Error, "Atom 7 has only 1 valence electron available" do
    #     glu_cd.bonds.add st.atoms[5], :double
    #   end
    # end

    # it "fails when adding a bond leads to an invalid valence on secondary atom" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1

    #   expect_raises Chem::Error, "Atom 8 has only 1 valence electron available" do
    #     st.atoms[5].bonds.add glu_oe1, :double
    #   end
    # end

    # it "fails when the primary atom has its valence shell already full" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double

    #   expect_raises Chem::Error, "Atom 8 has its valence shell already full" do
    #     glu_oe1.bonds.add glu_oe2
    #   end
    # end

    # it "fails when the secondary atom has its valence shell already full" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double

    #   expect_raises Chem::Error, "Atom 8 has its valence shell already full" do
    #     glu_oe2.bonds.add glu_oe1
    #   end
    # end

    # it "fails when a charged atom has its valence shell already full" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe2
    #   glu_oe2.charge.should eq -1

    #   expect_raises Chem::Error, "Atom 9 has its valence shell already full" do
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

describe Chem::Topology do
  describe "#delete" do
    it "deletes a chain" do
      top = Chem::Structure.build do
        3.times { chain { } }
      end.topology
      top.n_chains.should eq 3
      top.chains.map(&.id).should eq "ABC".chars

      top.delete top.chains[1]
      top.n_chains.should eq 2
      top.chains.map(&.id).should eq "AC".chars
      top.dig?('B').should be_nil
    end

    it "does not delete another chain with the same id from the internal table (#86)" do
      top = Chem::Topology.new
      Chem::Chain.new 'A', top
      Chem::Chain.new 'B', top
      Chem::Chain.new 'A', top

      top.n_chains.should eq 3
      top.chains.map(&.id).should eq "ABA".chars

      top.delete top.chains[0]

      top.n_chains.should eq 2
      top.chains.map(&.id).should eq "BA".chars
      top.dig('A').should be top.chains[1]
    end
  end

  describe "#dig" do
    top = fake_structure

    it "returns a chain" do
      top.dig('A').id.should eq 'A'
    end

    it "returns a residue" do
      top.dig('A', 2).name.should eq "PHE"
      top.dig('A', 2, nil).name.should eq "PHE"
    end

    it "returns an atom" do
      top.dig('A', 2, "CA").name.should eq "CA"
      top.dig('A', 2, nil, "CA").name.should eq "CA"
    end

    it "fails when index is invalid" do
      expect_raises(KeyError) { top.dig 'C' }
      expect_raises(KeyError) { top.dig 'A', 25 }
      expect_raises(KeyError) { top.dig 'A', 2, "OH" }
    end
  end

  describe "#dig?" do
    top = fake_structure

    it "returns nil when index is invalid" do
      top.dig?('C').should be_nil
      top.dig?('A', 25).should be_nil
      top.dig?('A', 2, "OH").should be_nil
    end
  end

  describe "#renumber_residues_by" do
    it "renumbers residues by the given order" do
      top = load_file("3sgr.pdb").topology
      expected = top.chains.map { |chain| chain.residues.sort_by!(&.code) }
      top.renumber_residues_by(&.code)
      top.chains.map(&.residues).should eq expected
    end
  end

  describe "#renumber_residues_by_connectivity" do
    it "renumbers residues in ascending order based on the link bond" do
      top = load_file("5e5v--unwrapped.poscar", guess_topology: true).topology
      top.renumber_residues_by_connectivity split_chains: false

      chains = top.chains
      chains[0].residues.map(&.number).should eq (1..7).to_a
      chains[0].residues.map(&.name).should eq %w(ASN PHE GLY ALA ILE LEU SER)
      chains[1].residues.map(&.number).should eq (1..7).to_a
      chains[1].residues.map(&.name).should eq %w(UNK PHE GLY ALA ILE LEU SER)
      chains[2].residues.map(&.name).should eq %w(HOH HOH HOH HOH HOH HOH HOH)
      chains[2].residues.map(&.number).should eq (1..7).to_a
      chains[3].residues.map(&.name).should eq %w(UNK)
      chains[3].residues.map(&.number).should eq [1]

      chains[0].residues[0].pred.should be_nil
      chains[0].residues[3].pred.try(&.name).should eq "GLY"
      chains[0].residues[3].succ.try(&.name).should eq "ILE"
      chains[0].residues[-1].succ.should be_nil
    end

    it "renumbers residues of a periodic peptide" do
      top = load_file("hlx_gly.poscar").topology
      top.each_residue.cons(2, reuse: true).each do |(a, b)|
        a["C"].bonded?(b["N"]).should be_true
        a.succ.should eq b
        b.pred.should eq a
      end
    end

    it "does not depend on current residue numbering (#82)" do
      [
        "polyala-trp--theta-80.000--c-19.91.poscar",
        "polyala-trp--theta-180.000--c-10.00.poscar",
      ].each do |filename|
        top = load_file(filename, guess_topology: true).topology
        top.renumber_residues_by_connectivity
        residues = top.residues.to_a.sort_by(&.number)
        residues.map(&.number).should eq (1..residues.size).to_a
        residues.each_with_index do |residue, i|
          j = i + 1
          j = 0 if j >= residues.size
          residues[j].number.should eq j + 1
          residue.bonded?(residues[j]).should be_true
        end
      end
    end

    it "does not split chains (#85)" do
      top = load_file("cylindrin--size-09.pdb").topology
      top.renumber_residues_by_connectivity split_chains: false
      top.chains.map(&.id).should eq "ABC".chars
      top.chains.map(&.n_residues).should eq [18] * 3
      top.chains.map(&.residues.map(&.number)).should eq [(1..18).to_a] * 3
      top.chains.map(&.residues.map(&.name)).should eq [
        %w(LEU LYS VAL LEU GLY ASP VAL ILE GLU LEU LYS VAL LEU GLY ASP VAL ILE GLU),
      ] * 3
    end

    it "splits chains (#85)" do
      top = load_file("cylindrin--size-09.pdb").topology
      top.renumber_residues_by_connectivity split_chains: true
      top.chains.map(&.id).should eq "ABCDEF".chars
      top.chains.map(&.n_residues).should eq [9] * 6
      top.chains.map(&.residues.map(&.number)).should eq [(1..9).to_a] * 6
      top.chains.map(&.residues.map(&.name)).should eq [
        %w(LEU LYS VAL LEU GLY ASP VAL ILE GLU),
      ] * 6
    end
  end
end
