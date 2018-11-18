require "../../spec_helper"

describe Chem::Residue do
  it "sets up conformations based on atom alternate locations" do
    residue = fake_residue_with_alternate_conformations
    residue.conformations.map(&.id).should eq ['A', 'B', 'C', 'D']
  end

  describe "conformations" do
    describe "#[]" do
      it "fails on unknown conformation id" do
        expect_raises Chem::Error, "A:SER1 does not have conformation Z" do
          residue = fake_residue_with_alternate_conformations
          residue.conformations['Z']
        end
      end
    end

    describe "#[]?" do
      it "gets conformation by id" do
        residue = fake_residue_with_alternate_conformations
        residue.conformations['B']?.try(&.id).should eq 'B'
      end

      it "returns nil on unknown conformation id" do
        residue = fake_residue_with_alternate_conformations
        residue.conformations['Z']?.should be_nil
      end
    end

    describe "#next" do
      it "changes to the next conformation" do
        residue = fake_residue_with_alternate_conformations

        confs = [{'A', 1, 0.65}, {'B', 2, 0.2}, {'C', 3, 0.1}, {'D', 4, 0.05}]
        confs.each.cycle(2) do |id, x, occ|
          residue.conf.try(&.id).should eq id
          residue.conf.try(&.occupancy).should eq occ
          xs = [0, 0, 0, 0, x, x]
          xs << x if id == 'D'
          residue.atoms.map(&.x).should eq xs
          residue.conformations.next
        end
      end
    end
  end

  describe "#conf" do
    it "returns current conformation" do
      residue = fake_residue_with_alternate_conformations
      residue.conf.should_not be_nil
      residue.conf.try(&.id).should eq 'A'
      residue.conf.try(&.occupancy).should eq 0.65
      residue.atoms.map(&.x).should eq [0, 0, 0, 0, 1, 1]
    end

    it "returns nil when there are no conformations" do
      residue = fake_structure.residues.first
      residue.conf.should be_nil
    end
  end

  describe "#conf=" do
    it "sets conformation by id" do
      residue = fake_residue_with_alternate_conformations
      residue.conf.try(&.id).should eq 'A'
      residue.conf = 'C'
      residue.conf.try(&.id).should eq 'C'
      residue.conf.try(&.occupancy).should eq 0.1
      residue.atoms.map(&.x).should eq [0, 0, 0, 0, 3, 3]
    end

    it "fails with unknown conformation" do
      expect_raises Chem::Error, "A:SER1 does not have conformation Z" do
        residue = fake_residue_with_alternate_conformations
        residue.conf = 'Z'
      end
    end
  end

  describe "#has_alternate_conformations?" do
    it "returns true when residue has alternate conformations" do
      residue = fake_residue_with_alternate_conformations
      residue.has_alternate_conformations?.should be_true
    end

    it "returns false when residue doesn't have alternate conformations" do
      residue = fake_structure.residues.first
      residue.has_alternate_conformations?.should be_false
    end
  end
end
