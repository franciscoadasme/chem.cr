require "../spec_helper"

describe Chem::ResidueCollection do
  describe "#each_secondary_structure" do
    it "iterates over secondary structure elements" do
      ary = [] of Tuple(Chem::Protein::SecondaryStructure, Range(Int32, Int32))
      s = Chem::Structure.from_pdb "spec/data/pdb/3sgr.pdb", chains: "BEF".chars
      s.each_secondary_structure do |ele, sec|
        ary << {sec, ele[0].number..ele[-1].number}
      end

      ary.should eq [
        {sec(:none), 0..1},
        {sec(:beta_strand), 2..11},
        {sec(:none), 12..13},
        {sec(:beta_strand), 14..23},
        {sec(:none), 24..24},
        {sec(:none), 0..0},
        {sec(:beta_strand), 1..11},
        {sec(:none), 12..13},
        {sec(:beta_strand), 14..24},
        {sec(:none), 0..1},
        {sec(:beta_strand), 2..11},
        {sec(:none), 12..13},
        {sec(:beta_strand), 14..23},
        {sec(:none), 24..24},
      ]
    end

    it "iterates over secondary structure elements non-strictly" do
      s = load_file "hlx_gly.poscar"
      builder = Chem::Structure::Builder.new s
      builder.secondary_structure({'A', 2, nil}, {'A', 4, nil}, :right_handed_helix_alpha)
      builder.secondary_structure({'A', 5, nil}, {'A', 8, nil}, :right_handed_helix3_10)
      builder.secondary_structure({'A', 9, nil}, {'A', 10, nil}, :none)
      builder.secondary_structure({'A', 11, nil}, {'A', 13, nil}, :beta_strand)

      ary = [] of Range(Int32, Int32)
      s.each_secondary_structure(strict: false) do |ele, _|
        ary << (ele[0].number..ele[-1].number)
      end
      ary.should eq [1..1, 2..8, 9..10, 11..13]
    end

    it "returns an iterator over secondary structure elements" do
      s = Chem::Structure.from_pdb "spec/data/pdb/3sgr.pdb", chains: "BEF".chars
      s.each_secondary_structure
        .to_a
        .map { |ele| ele[0].number..ele[-1].number }
        .should eq [
          0..1, 2..11, 12..13, 14..23, 24..24,
          0..0, 1..11, 12..13, 14..24,
          0..1, 2..11, 12..13, 14..23, 24..24,
        ]
    end

    it "returns an iterator over secondary structure elements non-strictly" do
      s = load_file "hlx_gly.poscar"
      builder = Chem::Structure::Builder.new s
      builder.secondary_structure({'A', 1, nil}, {'A', 5, nil}, :right_handed_helix_alpha)
      builder.secondary_structure({'A', 6, nil}, {'A', 10, nil}, :right_handed_helix3_10)
      builder.secondary_structure({'A', 11, nil}, {'A', 11, nil}, :none)
      builder.secondary_structure({'A', 12, nil}, {'A', 13, nil}, :beta_strand)

      s.each_secondary_structure(strict: false)
        .to_a
        .map { |ele| ele[0].number..ele[-1].number }
        .should eq [1..10, 11..11, 12..13]
    end
  end

  describe "#each_residue" do
    it "iterates over each residue when called with block" do
      ary = [] of String
      fake_structure.each_residue { |residue| ary << residue.name }
      ary.should eq ["ASP", "PHE", "SER"]
    end

    it "returns an iterator when called without block" do
      fake_structure.each_residue.should be_a Iterator(Chem::Residue)
    end
  end

  describe "#n_residues" do
    it "returns the number of residues" do
      fake_structure.n_residues.should eq 3
    end
  end

  describe "#renumber_by_connectivity" do
    it "renumbers residues in ascending order based on the link bond" do
      structure = load_file "5e5v--unwrapped.poscar", topology: :guess
      structure.renumber_by_connectivity

      chains = structure.chains
      chains[0].residues.map(&.number).should eq (1..7).to_a
      chains[0].residues.map(&.name).should eq %w(ASN PHE GLY ALA ILE LEU SER)
      chains[1].residues.map(&.number).should eq (1..7).to_a
      chains[1].residues.map(&.name).should eq %w(UNK PHE GLY ALA ILE LEU SER)
      chains[2].residues.map(&.name).should eq %w(HOH HOH HOH HOH HOH HOH HOH)
      chains[2].residues.map(&.number).should eq (1..7).to_a
      chains[3].residues.map(&.name).should eq %w(UNK)
      chains[3].residues.map(&.number).should eq [1]

      chains[0].residues[0].previous.should be_nil
      chains[0].residues[3].previous.try(&.name).should eq "GLY"
      chains[0].residues[3].next.try(&.name).should eq "ILE"
      chains[0].residues[-1].next.should be_nil
    end

    it "renumbers residues of a periodic peptide" do
      structure = load_file "hlx_gly.poscar", topology: :renumber

      structure.each_residue.cons(2, reuse: true).each do |(a, b)|
        a["C"].bonded?(b["N"]).should be_true
        a.next.should eq b
        b.previous.should eq a
      end
    end
  end

  describe "#reset_secondary_structure" do
    it "sets secondary structure to none" do
      s = load_file "1crn.pdb"
      s.reset_secondary_structure
      s.each_residue.all?(&.sec.none?).should be_true
    end
  end

  describe "#residues" do
    it "returns a residue view" do
      fake_structure.residues.should be_a Chem::ResidueView
    end
  end
end
