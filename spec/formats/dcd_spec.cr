require "../spec_helper"

describe Chem::DCD do
  describe ".each" do
    it "yields each positions entry" do
      count = 0
      Chem::DCD.each(spec_file("water.dcd")) do
        count += 1
      end
      count.should eq 100
    end
  end

  describe ".read" do
    it "reads the first entry" do
      pos = Chem::DCD.read spec_file("water.dcd")
      pos[0].should be_close vec3(0.41721907, 8.303366, 11.737172), 1e-6
      pos[296].should be_close vec3(6.664049, 11.614183, 12.961486), 1e-6

      pos.cell?.should_not be_nil
      pos.cell.size.should eq [15, 15, 15]
      pos.cell.angles.should eq({90, 90, 90})
    end

    it "reads an entry at a specific index" do
      pos = Chem::DCD.read spec_file("water.dcd"), index: 2
      pos[0].should be_close vec3(0.29909524, 8.31003, 11.721462), 1e-6
      pos[296].should be_close vec3(6.797599, 11.50882, 12.704233), 1e-6
    end

    it "sets cell to nil if missing" do
      pos = Chem::DCD.read spec_file("nopbc.dcd")
      pos.cell?.should be_nil
    end

    it "reads an orthorhombic cell" do
      pos = Chem::DCD.read spec_file("withpbc.dcd")
      pos.size.should eq 364
      pos.cell?.should_not be_nil
      pos.cell.size.should eq [100, 100, 100]
      pos.cell.angles.should eq({90, 90, 90})
    end

    it "reads a triclinic cell" do
      pos = Chem::DCD.read spec_file("triclinic-octane-direct.dcd")
      pos.size.should eq 13
      pos.cell?.should_not be_nil
      pos.cell.size.should be_close [4.109898, 4.707060, 10.993230], 1e-6
      pos.cell.angles.should be_close({105.571273, 73.688987, 125.133354}, 1e-6)
    end

    it "reads a triclinic cell with cosine angles" do
      pos = Chem::DCD.read spec_file("triclinic-octane-cos.dcd")
      pos.size.should eq 13
      pos.cell?.should_not be_nil
      pos.cell.size.should be_close [4.109898, 4.707060, 10.993230], 1e-6
      pos.cell.angles.should be_close({105.571274, 73.688985, 125.133355}, 1e-6)
    end

    it "reads cell vectors" do
      pos = Chem::DCD.read spec_file("triclinic-octane-vectors.dcd")
      pos.size.should eq 13
      pos.cell?.should_not be_nil
      pos.cell.size.should be_close [4.1594858, 4.749700, 11.000093], 1e-6
      pos.cell.angles.should be_close({94.804658, 84.486392, 105.108346}, 1e-6)
    end

    it "reads a cell from NAMD" do
      pos = Chem::DCD.read spec_file("triclinic-namd.dcd")
      pos.size.should eq 9999
      pos.cell?.should_not be_nil
      pos.cell.size.should be_close [85.440037, 89.442719, 85.440037], 1e-6
      pos.cell.angles.should be_close({65.244990, 70.806038, 71.696265}, 1e-6)
      pos.cell.volume.should be_close 548000, 1e-6
    end

    it "reads a 4D DCD" do
      pos = Chem::DCD.read spec_file("4d-dynamic.dcd")
      pos.size.should eq 27
      pos.cell?.should be_nil
      pos[5].should be_close vec3(-1.5822195, 0.6511365, 1.3911803), 1e-6
      pos[15].should be_close vec3(2.2381972, -0.5173331, -0.4879273), 1e-6

      pos = Chem::DCD.read spec_file("4d-dynamic.dcd"), index: 3
      pos.size.should eq 27
      pos.cell?.should be_nil
      pos[5].should be_close vec3(-1.5833939, 0.70485264, 1.3606575), 1e-6
      pos[15].should be_close vec3(2.230041, -0.5253474, -0.50111574), 1e-6
    end

    it "reads fixed atoms" do
      pos = Chem::DCD.read spec_file("fixed-atoms.dcd")
      pos.size.should eq 12
      pos.cell?.should be_nil
      pos[2].should be_close vec3(-1.0220516, -1.0135641, 0), 1e-6
      pos[10].should be_close vec3(1.820057, -1.3015488, 10), 1e-6

      pos = Chem::DCD.read spec_file("fixed-atoms.dcd"), index: 1
      pos.size.should eq 12
      pos.cell?.should be_nil
      pos[2].should be_close vec3(-1.0220516, -1.0135641, 0), 1e-6
      pos[10].should be_close vec3(1.8200468, -1.3015325, 10), 1e-6

      pos = Chem::DCD.read spec_file("fixed-atoms.dcd"), index: 5
      pos.size.should eq 12
      pos.cell?.should be_nil
      pos[2].should be_close vec3(-1.0220516, -1.0135641, 0), 1e-6
      pos[10].should be_close vec3(1.8199368, -1.3013588, 10), 1e-6
    end

    it "reads big endian" do
      pos = Chem::DCD.read spec_file("mrmd_h2so4-32bit-be.dcd"), index: 23
      pos.size.should eq 7
      pos.cell?.should be_nil
      pos[2].should be_close vec3(0.6486294, 0.062248673, -1.5570515), 1e-6
      pos[4].should be_close vec3(-1.3111109, 0.35563222, 0.9946163), 1e-6
    end

    it "reads 64-bit markers" do
      pos = Chem::DCD.read spec_file("mrmd_h2so4-64bit-le.dcd"), index: 23
      pos.size.should eq 7
      pos.cell?.should be_nil
      pos[2].should be_close vec3(0.6486294, 0.062248673, -1.5570515), 1e-6
      pos[4].should be_close vec3(-1.3111109, 0.35563222, 0.9946163), 1e-6
    end

    it "reads 64-bit markers (big endian)" do
      pos = Chem::DCD.read spec_file("mrmd_h2so4-64bit-be.dcd"), index: 23
      pos.size.should eq 7
      pos.cell?.should be_nil
      pos[2].should be_close vec3(0.6486294, 0.062248673, -1.5570515), 1e-6
      pos[4].should be_close vec3(-1.3111109, 0.35563222, 0.9946163), 1e-6
    end
  end

  describe ".read_all" do
    it "reads all frames" do
      frames = Chem::DCD.read_all spec_file("water.dcd")
      frames.size.should eq 100

      frames[0].size.should eq 297
      frames[0][0].should be_close vec3(0.41721907, 8.303366, 11.737172), 1e-6
      frames[0][296].should be_close vec3(6.664049, 11.614183, 12.961486), 1e-6

      frames[-1].size.should eq 297
      frames[-1][0].should be_close vec3(0.318559, 8.776042, 11.892704), 1e-6
      frames[-1][296].should be_close vec3(7.089802, 10.350066, 12.815898), 1e-6
    end
  end

  describe ".write" do
    it "writes frames" do
      orig_traj = Array.new(10) { fake_positions(3) }

      # test both indexable and enumerable (iterator)
      {orig_traj, orig_traj.each}.each do |traj|
        io = IO::Memory.new
        Chem::DCD.write(io, traj)

        io.rewind

        traj = Chem::DCD.read_all io
        traj.size.should eq orig_traj.size
        traj.each_with_index do |pos, i|
          pos.size.should eq orig_traj[i].size
          pos.cell?.should eq orig_traj[i].cell?
          pos[0].should be_close orig_traj[i][0], 1e-6
          pos[1].should be_close orig_traj[i][1], 1e-6
          pos[2].should be_close orig_traj[i][2], 1e-6
        end
      end
    end

    it "raises on different size" do
      expect_raises ArgumentError, "Cannot write frames with different size" do
        Chem::DCD.write IO::Memory.new, [fake_positions(3), fake_positions(10)]
      end
    end
  end
end

private def fake_positions(size : Int) : Chem::Spatial::Positions3
  slice = Slice.new(size) { Chem::Spatial::Vec3.rand }
  cell = Chem::Spatial::Parallelepiped[rand(1.0..10.0), rand(10.0..20.0), rand(20.0..30.0)]
  Chem::Spatial::Positions3.new slice, cell
end
