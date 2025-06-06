require "../spec_helper"

describe Chem::DCD::Reader do
  it "reads a DCD file" do
    Chem::DCD::Reader.open(spec_file("water.dcd")) do |reader|
      reader.n_entries.should eq 100

      pos = reader.read_entry
      pos[0].should be_close vec3(0.41721907, 8.303366, 11.737172), 1e-6
      pos[296].should be_close vec3(6.664049, 11.614183, 12.961486), 1e-6

      pos.cell?.should_not be_nil
      pos.cell.size.should eq [15, 15, 15]
      pos.cell.angles.should eq({90, 90, 90})

      pos = reader.read_entry 2
      pos[0].should be_close vec3(0.29909524, 8.31003, 11.721462), 1e-6
      pos[296].should be_close vec3(6.797599, 11.50882, 12.704233), 1e-6
    end
  end

  it "sets cell to nil if missing" do
    Chem::DCD::Reader.open(spec_file("nopbc.dcd")) do |reader|
      pos = reader.read_entry
      pos.cell?.should be_nil
    end
  end

  it "reads an orthorhombic cell" do
    Chem::DCD::Reader.open(spec_file("withpbc.dcd")) do |reader|
      pos = reader.read_entry
      pos.size.should eq 364
      pos.cell?.should_not be_nil
      pos.cell.size.should eq [100, 100, 100]
      pos.cell.angles.should eq({90, 90, 90})
    end
  end

  it "reads a triclinic cell" do
    Chem::DCD::Reader.open(spec_file("triclinic-octane-direct.dcd")) do |reader|
      reader.n_entries.should eq 10

      pos = reader.read_entry
      pos.size.should eq 13
      pos.cell?.should_not be_nil
      pos.cell.size.should be_close [4.109898, 4.707060, 10.993230], 1e-6
      pos.cell.angles.should be_close({105.571273, 73.688987, 125.133354}, 1e-6)
    end
  end

  it "reads a triclinic cell with cosine angles" do
    Chem::DCD::Reader.open(spec_file("triclinic-octane-cos.dcd")) do |reader|
      reader.n_entries.should eq 10

      pos = reader.read_entry
      pos.size.should eq 13
      pos.cell?.should_not be_nil
      pos.cell.size.should be_close [4.109898, 4.707060, 10.993230], 1e-6
      pos.cell.angles.should be_close({105.571274, 73.688985, 125.133355}, 1e-6)
    end
  end

  it "reads cell vectors" do
    Chem::DCD::Reader.open(spec_file("triclinic-octane-vectors.dcd")) do |reader|
      reader.n_entries.should eq 10

      pos = reader.read_entry
      pos.size.should eq 13
      pos.cell?.should_not be_nil
      pos.cell.size.should be_close [4.1594858, 4.749700, 11.000093], 1e-6
      pos.cell.angles.should be_close({94.804658, 84.486392, 105.108346}, 1e-6)
    end
  end

  it "reads a cell from NAMD" do
    Chem::DCD::Reader.open(spec_file("triclinic-namd.dcd")) do |reader|
      reader.n_entries.should eq 1

      pos = reader.read_entry
      pos.size.should eq 9999
      pos.cell?.should_not be_nil
      pos.cell.size.should be_close [85.440037, 89.442719, 85.440037], 1e-6
      pos.cell.angles.should be_close({65.244990, 70.806038, 71.696265}, 1e-6)
      pos.cell.volume.should be_close 548000, 1e-6
    end
  end

  it "reads a 4D DCD" do
    Chem::DCD::Reader.open(spec_file("4d-dynamic.dcd")) do |reader|
      reader.n_entries.should eq 5

      pos = reader.read_entry
      pos.size.should eq 27
      pos.cell?.should be_nil
      pos[5].should be_close vec3(-1.5822195, 0.6511365, 1.3911803), 1e-6
      pos[15].should be_close vec3(2.2381972, -0.5173331, -0.4879273), 1e-6

      pos = reader.read_entry 3
      pos.size.should eq 27
      pos.cell?.should be_nil
      pos[5].should be_close vec3(-1.5833939, 0.70485264, 1.3606575), 1e-6
      pos[15].should be_close vec3(2.230041, -0.5253474, -0.50111574), 1e-6
    end
  end

  it "reads fixed atoms" do
    Chem::DCD::Reader.open(spec_file("fixed-atoms.dcd")) do |reader|
      reader.n_entries.should eq 10

      pos = reader.read_entry
      pos.size.should eq 12
      pos.cell?.should be_nil
      pos[2].should be_close vec3(-1.0220516, -1.0135641, 0), 1e-6
      pos[10].should be_close vec3(1.820057, -1.3015488, 10), 1e-6

      pos = reader.read_entry
      pos.size.should eq 12
      pos.cell?.should be_nil
      pos[2].should be_close vec3(-1.0220516, -1.0135641, 0), 1e-6
      pos[10].should be_close vec3(1.8200468, -1.3015325, 10), 1e-6

      pos = reader.read_entry 5
      pos.size.should eq 12
      pos.cell?.should be_nil
      pos[2].should be_close vec3(-1.0220516, -1.0135641, 0), 1e-6
      pos[10].should be_close vec3(1.8199368, -1.3013588, 10), 1e-6
    end
  end

  it "reads big endian" do
    Chem::DCD::Reader.open(spec_file("mrmd_h2so4-32bit-be.dcd")) do |reader|
      reader.n_entries.should eq 50

      pos = reader.read_entry 23
      pos.size.should eq 7
      pos.cell?.should be_nil
      pos[2].should be_close vec3(0.6486294, 0.062248673, -1.5570515), 1e-6
      pos[4].should be_close vec3(-1.3111109, 0.35563222, 0.9946163), 1e-6
    end
  end

  it "reads 64-bit markers" do
    Chem::DCD::Reader.open(spec_file("mrmd_h2so4-64bit-le.dcd")) do |reader|
      reader.n_entries.should eq 50

      pos = reader.read_entry 23
      pos.size.should eq 7
      pos.cell?.should be_nil
      pos[2].should be_close vec3(0.6486294, 0.062248673, -1.5570515), 1e-6
      pos[4].should be_close vec3(-1.3111109, 0.35563222, 0.9946163), 1e-6
    end
  end

  it "reads 64-bit markers (big endian)" do
    Chem::DCD::Reader.open(spec_file("mrmd_h2so4-64bit-be.dcd")) do |reader|
      reader.n_entries.should eq 50

      pos = reader.read_entry 23
      pos.size.should eq 7
      pos.cell?.should be_nil
      pos[2].should be_close vec3(0.6486294, 0.062248673, -1.5570515), 1e-6
      pos[4].should be_close vec3(-1.3111109, 0.35563222, 0.9946163), 1e-6
    end
  end
end

describe Chem::DCD::Writer do
  it "writes a DCD" do
    traj = Array.new(10) { fake_positions(3) }

    io = IO::Memory.new
    Chem::DCD::Writer.open(io) do |writer|
      traj.each { |pos| writer << pos }
    end

    io.rewind
    Chem::DCD::Reader.open(io) do |reader|
      reader.n_entries.should eq 10

      pos = reader.read_entry
      pos.size.should eq 3
      pos.cell?.should_not be_nil
      pos.cell.should eq traj[0].cell
      pos[0].should be_close traj[0][0], 1e-6
      pos[1].should be_close traj[0][1], 1e-6
      pos[2].should be_close traj[0][2], 1e-6

      pos = reader.read_entry(9)
      pos.size.should eq 3
      pos.cell?.should_not be_nil
      pos.cell.should eq traj[-1].cell
      pos[0].should be_close traj[-1][0], 1e-6
      pos[1].should be_close traj[-1][1], 1e-6
      pos[2].should be_close traj[-1][2], 1e-6
    end
  end
end

private def fake_positions(size : Int) : Chem::Spatial::Positions3
  slice = Slice.new(size) { Chem::Spatial::Vec3.rand }
  cell = Chem::Spatial::Parallelepiped[rand(1.0..10.0), rand(10.0..20.0), rand(20.0..30.0)]
  Chem::Spatial::Positions3.new slice, cell
end
