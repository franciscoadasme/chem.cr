require "../spec_helper"

describe Chem::SDF do
  describe ".each" do
    it "yields each structure" do
      count = 0
      Chem::SDF.each spec_file("0B1.sdf") do
        count += 1
      end
      count.should eq 172
    end
  end

  describe ".read" do
    it "reads the first structure from a SDF file" do
      path = Path[spec_file("0B1.sdf")]
      struc = Chem::SDF.read path
      struc.source_file.should eq path.expand
      struc.atoms.size.should eq 47
      struc.bonds.size.should eq 50
      struc.cell?.should be_nil
      struc.metadata.keys.should eq %w(cid energy)
      struc.metadata["cid"].should eq 42
      struc.metadata["energy"].should eq -69.2498879662534
    end
  end

  describe ".read_all" do
    it "returns all structures" do
      path = Path[spec_file("0B1.sdf")]
      structures = Chem::SDF.read_all path
      structures.size.should eq 172
      structures.each do |struc|
        struc.source_file.should eq path.expand
        struc.cell?.should be_nil
        struc.atoms.size.should eq 47
        struc.bonds.size.should eq 50
        struc.metadata.keys.should eq %w(cid energy)
        struc.metadata["cid"].raw.should be_a Int32
        struc.metadata["energy"].raw.should be_a Float64
      end

      structures[0].metadata["cid"].should eq 42
      structures[0].metadata["energy"].should eq -69.2498879662534

      structures[86].metadata["cid"].should eq 95
      structures[86].metadata["energy"].should eq -66.80468478035203
    end
  end

  describe ".write" do
    it "writes structures" do
      expected = File.read(spec_file("0B1_3-4_chem.sdf"))
        .gsub "1018231427", Time.local.to_s("%m%d%y%H%M")
      structures = Chem::SDF.read_all spec_file("0B1.sdf")

      io = IO::Memory.new
      Chem::SDF.write(io, structures[2..3])
      io.to_s.should eq expected
    end
  end
end
