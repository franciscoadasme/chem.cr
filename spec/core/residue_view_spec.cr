require "../spec_helper"

describe Chem::ResidueView do
  residues = load_file("insertion_codes.pdb").residues

  describe "#[]" do
    it "gets residue by zero-based index" do
      residues[1].name.should eq "GLY"
    end
  end

  describe "#chains" do
    it "returns the enclosing chains" do
      fake_structure.residues.chains.map(&.id).should eq ['A', 'B']
    end
  end

  describe "#each_secondary_structure" do
    it "iterates over secondary structure elements" do
      ary = [] of Tuple(Chem::Protein::SecondaryStructure, Range(Int32, Int32))
      s = Chem::Structure.from_pdb spec_file("3sgr.pdb"), chains: "BEF".chars
      s.residues.each_secondary_structure do |ele, sec|
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
      s = load_file "hlx_gly.poscar", guess_bonds: true, guess_names: true
      residues = s.dig('A').residues
      residues.each within: 1..3, &.sec=(:right_handed_helix_alpha)
      residues.each within: 4..7, &.sec=(:right_handed_helix3_10)
      residues.each within: 8..9, &.sec=(:none)
      residues.each within: 10..12, &.sec=(:beta_strand)

      ary = [] of Range(Int32, Int32)
      s.residues.each_secondary_structure(strict: false) do |ele, _|
        ary << (ele[0].number..ele[-1].number)
      end
      ary.should eq [1..1, 2..8, 9..10, 11..13]
    end

    it "returns an iterator over secondary structure elements" do
      s = Chem::Structure.from_pdb spec_file("3sgr.pdb"), chains: "BEF".chars
      s.residues.each_secondary_structure
        .to_a
        .map { |ele| ele[0].number..ele[-1].number }
        .should eq [
          0..1, 2..11, 12..13, 14..23, 24..24,
          0..0, 1..11, 12..13, 14..24,
          0..1, 2..11, 12..13, 14..23, 24..24,
        ]
    end

    it "returns an iterator over secondary structure elements non-strictly" do
      s = load_file "hlx_gly.poscar", guess_bonds: true, guess_names: true
      residues = s.dig('A').residues
      residues.each within: 0..4, &.sec=(:right_handed_helix_alpha)
      residues.each within: 5..9, &.sec=(:right_handed_helix3_10)
      residues.each within: 10..10, &.sec=(:none)
      residues.each within: 11..12, &.sec=(:beta_strand)

      s.residues.each_secondary_structure(strict: false)
        .to_a
        .map { |ele| ele[0].number..ele[-1].number }
        .should eq [1..10, 11..11, 12..13]
    end
  end

  describe "#reset_secondary_structure" do
    it "sets secondary structure to none" do
      s = load_file "1crn.pdb"
      s.residues.reset_secondary_structure
      s.residues.all?(&.sec.none?).should be_true
    end
  end

  describe "#residue_fragments" do
    it "returns fragments of residues" do
      structure = load_file("cylindrin--size-09.pdb")
      fragments = structure.residues.residue_fragments
      fragments.size.should eq 6
      fragments.map(&.size).should eq [9] * 6
      fragments.map(&.map(&.chain.id).uniq!.join).should eq %w(A A B B C C)
      fragments.map(&.map(&.number)).should eq [(2..10).to_a, (15..23).to_a] * 3
      fragments.map(&.map(&.name)).should eq [%w(LEU LYS VAL LEU GLY ASP VAL ILE GLU)] * 6
    end
  end
end
