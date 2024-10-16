require "../spec_helper"

describe Enumerable do
  describe "#average" do
    it "returns the weighted average" do
      (1..9).average((0..8).to_a).should eq 20 / 3
      (1..9).to_a.average((0..8).to_a).should eq 20 / 3
    end

    it "returns the weighted average with block" do
      (1..9).average((0..8).to_a, &.**(2)).should eq 145 / 3
      (1..9).to_a.average((0..8).to_a, &.**(2)).should eq 145 / 3
      ["Alice", "Bob"].average([7, 2], &.size).should eq 4.555555555555555
      ('a'..'z').average((0..25).to_a, &.ord).should eq 114
    end

    it "raises if incompatible sizes" do
      expect_raises(ArgumentError) { (1..5).average([0, 1]) }
      expect_raises(ArgumentError) { [1, 2, 3, 4].average([0, 1, 2]) }
    end

    it "raises if empty" do
      expect_raises(Enumerable::EmptyError) { ([] of Int32).average([1, 1, 1]) }
    end
  end

  describe "#find" do
    it "searches by pattern" do
      [1, 3, 2, 5, 4, 6].find(3..5).should eq 3
      ["Alice", "Bob"].find(/^A/).should eq "Alice"
      [1, 2, 3, 4].find(8..).should be_nil
    end
  end

  describe "#find!" do
    it "searches by pattern" do
      [1, 3, 2, 5, 4, 6].find!(3..5).should eq 3
      ["Alice", "Bob"].find!(/^A/).should eq "Alice"
      expect_raises(Enumerable::NotFoundError) do
        [1, 2, 3, 4].find!(8..)
      end
    end
  end

  describe "#mean" do
    it "returns the mean" do
      (1..40).mean.should eq 20.5
    end

    it "returns the mean with block" do
      (1..22).mean(&.**(2)).should eq 172.5
      ["Alice", "Bob"].mean(&.size).should eq 4
      ('a'..'z').mean(&.ord).should eq 109.5
    end

    it "raises if empty" do
      expect_raises(Enumerable::EmptyError) { ([] of Int32).mean }
    end
  end

  describe "#select" do
    it "selects by number" do
      struc = fake_structure
      struc.atoms.select(1).should eq struc.atoms[[0]]
      struc.atoms.select([1, 3, 5, 7]).should eq struc.atoms[[0, 2, 4, 6]]
      struc.atoms.select(1..3).should eq struc.atoms[0..2]

      struc.residues.select(..2).should eq struc.residues
    end

    it "selects by name" do
      struc = fake_structure
      struc.atoms.select("N").size.should eq 3
      struc.atoms.select("CA").size.should eq 3
      struc.atoms.select(/C[ABGDEZ]\d*/).size.should eq 13
      struc.atoms.select(%w(N CA C)).size.should eq 9

      struc.residues.select(/AS[PH]/).should eq struc.residues[...1]
      struc.residues.select('F').should eq struc.residues[1, 1]
      struc.residues.select("FD".chars).should eq struc.residues[0, 2]

      struc.chains.select('A').should eq [struc.chains[0]]
    end
  end
end
