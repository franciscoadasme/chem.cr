require "../spec_helper"

describe Chem::Protein::Stride do
  it "assigns secondary structure (1cbn)" do
    structure = Chem::Structure.read "spec/data/pdb/1cbn.pdb"
    structure.each_residue.select(&.has_alternate_conformations?).each &.conf=('A')

    Chem::Topology.guess_topology structure
    Chem::Protein::Stride.assign structure
    expected = "0EE000HHHHHHHHHHHH0000HHHHHHHH00EE000000TTTTT0"
    structure.each_residue.select(&.protein?).map(&.dssp).join.should eq expected
  end

  it "assigns secondary structure (5jqf)" do
    structure = Chem::Structure.read "spec/data/pdb/5jqf.pdb"
    structure.each_residue.select(&.has_alternate_conformations?).each &.conf=('A')

    Chem::Topology.guess_topology structure
    Chem::Protein::Stride.assign structure
    expected = "00B0000BTTTTT0BTTEEE000B0000BTTTTT0B00EEE0"
    structure.each_residue.select(&.protein?).map(&.dssp).join.should eq expected
  end

  it "assigns secondary structure (1dpo, insertion codes)" do
    structure = Chem::Structure.read "spec/data/pdb/1dpo.pdb"
    structure.each_residue.select(&.has_alternate_conformations?).each &.conf=('A')

    Chem::Topology.guess_topology structure
    Chem::Protein::Stride.assign structure
    structure['A'][183].secondary_structure.beta_strand?.should be_true
    structure['A'][184].secondary_structure.none?.should be_true
    structure['A'][184, 'A'].secondary_structure.turn?.should be_true
  end

  it "calculates secondary structure (1cbn)" do
    structure = Chem::Structure.read "spec/data/pdb/1cbn.pdb"
    structure.each_residue.select(&.has_alternate_conformations?).each &.conf=('A')

    Chem::Topology.guess_topology structure
    ss_table = Chem::Protein::Stride.calculate structure
    ss_table[structure['A'][7]].helix_alpha?.should be_true
    ss_table[structure['A'][45]].turn?.should be_true
    ss_table[structure['A'][46]].none?.should be_true
  end
end
