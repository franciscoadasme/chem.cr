require "../spec_helper"

describe Chem::Protein::Stride do
  it "assigns secondary structure (1cbn)" do
    structure = Chem::Structure.read "spec/data/pdb/1cbn.pdb"
    structure.each_residue.select(&.has_alternate_conformations?).each &.conf=('A')

    Chem::Topology.guess_topology structure
    Chem::Protein::Stride.assign_secondary_structure structure
    expected = "0EE000HHHHHHHHHHHH0000HHHHHHHH00EE000000TTTTT0"
    structure.each_residue.select(&.protein?).map(&.dssp).join.should eq expected
  end

  it "assigns secondary structure (5jqf)" do
    structure = Chem::Structure.read "spec/data/pdb/5jqf.pdb"
    structure.each_residue.select(&.has_alternate_conformations?).each &.conf=('A')

    Chem::Topology.guess_topology structure
    Chem::Protein::Stride.assign_secondary_structure structure
    expected = "00B0000BTTTTT0BTTEEE000B0000BTTTTT0B00EEE0"
    structure.each_residue.select(&.protein?).map(&.dssp).join.should eq expected
  end
end
