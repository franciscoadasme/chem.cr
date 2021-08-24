require "../spec_helper"

describe Array do
  describe ".read" do
    it "returns the entries in a file" do
      x = Array(Chem::Structure).read "spec/data/pdb/models.pdb"
      x.size.should eq 4
    end

    it "raises for a single-entry format" do
      expect_raises ArgumentError, "Poscar format cannot read Array(Chem::Structure)" do
        Array(Chem::Structure).read(IO::Memory.new, :poscar)
      end
    end

    it "raises if format does not decode the given type" do
      expect_raises ArgumentError, "DX format cannot read Array(Chem::Structure)" do
        Array(Chem::Structure).read(IO::Memory.new, :dx)
      end
    end

    it "fails for non-encoded types" do
      assert_error "Array(Int32).read(IO::Memory.new, :xyz)",
        "undefined method 'read' for Array(Int32).class"
    end

    it "fails with an array for a single-entry type" do
      assert_error "Array(Chem::Spatial::Grid).read IO::Memory.new, :xyz",
        "undefined method 'read' for Array(Chem::Spatial::Grid).class"
    end
  end

  describe "#sort!" do
    it "doesn't change the array with a negative- or zero-sized range" do
      ary = [94, 70, 52, 54, 66, 95, 58, 55, 95, 88, 98, 4, 45, 95]
      ary.sort! 5..2
      ary.should eq [94, 70, 52, 54, 66, 95, 58, 55, 95, 88, 98, 4, 45, 95]
    end

    it "sorts in-place the values within the given range" do
      ary = [14, 94, 70, 52, 54, 66, 95, 58, 55, 95]
      ary.sort! 0..4
      ary.should eq [14, 52, 54, 70, 94, 66, 95, 58, 55, 95]
    end

    it "sorts in-place the values within the given range (negative index)" do
      ary = [14, 94, 70, 52, 54, 66, 95, 58, 55, 95]
      ary.sort! 2..-4
      ary.should eq [14, 94, 52, 54, 66, 70, 95, 58, 55, 95]
    end

    it "sorts in-place the values within the given range with block" do
      ary = [94, 70, 52, 54, 66, 95, 58, 55, 95, 88, 98, 4, 45, 95]
      ary.sort! 6..-2 { |a, b| b <=> a }
      ary.should eq [94, 70, 52, 54, 66, 95, 98, 95, 88, 58, 55, 45, 4, 95]
    end

    it "fails with invalid range" do
      expect_raises IndexError do
        [94, 70, 52, 54, 66].sort! 6..-1
      end
    end
  end

  describe "#write" do
    it "writes in a multiple-entry format" do
      x = Array(Chem::Structure).from_pdb "spec/data/pdb/models.pdb"
      String.build { |io| x.write(io, :xyz) }.should eq <<-XYZ
        5

        N          5.60600        4.54600       11.94100
        C          5.59800        5.76700       11.08200
        C          6.44100        5.52700        9.85000
        O          6.05200        5.93300        8.74400
        C          6.02200        6.97700       11.89100
        5

        N          7.21200       15.33400        0.96600
        C          6.61400       16.31700        1.91300
        C          5.21200       15.93600        2.35000
        O          4.78200       16.16600        3.49500
        C          6.60500       17.69500        1.24600
        5

        N          5.40800       13.01200        4.69400
        C          5.87900       13.50200        6.02600
        C          4.69600       13.90800        6.88200
        O          4.52800       13.42200        8.02500
        C          6.88000       14.61500        5.83000
        5

        N         22.05500       14.70100        7.03200
        C         22.01900       13.24200        7.02000
        C         21.94400       12.62800        8.39600
        O         21.86900       11.38700        8.43500
        C         23.24600       12.69700        6.27500

        XYZ
    end

    it "raises for a single-entry format" do
      expect_raises ArgumentError, "Poscar format cannot write Array(Chem::Structure)" do
        Array(Chem::Structure).new.write(IO::Memory.new, :poscar)
      end
    end

    it "fails for non-encoded types" do
      assert_error "[1].write(IO::Memory.new, :xyz)",
        "undefined method 'write' for Array(Int32)"
    end

    it "fails with an array for a single-entry type" do
      assert_error "Array(Chem::Spatial::Grid).new.write IO::Memory.new, :xyz",
        "undefined method 'write' for Array(Chem::Spatial::Grid)"
    end
  end
end
