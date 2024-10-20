require "../spec_helper"

describe Chem::DCD::Reader do
  it "reads a DCD file" do
    structure = fake_structure size: 297
    Chem::DCD::Reader.open(spec_file("water.dcd"), structure) do |reader|
      reader.n_entries.should eq 100

      structure = reader.read_entry
      structure.metadata.keys.sort!.should eq %w(time)
      structure.metadata["time"]?.should eq 0
      structure.title.should eq \
        "Created by DCD plugin\nREMARKS Created 30 May, 2015 at 19:24\n"
      structure.atoms[0].pos.should be_close vec3(0.41721907, 8.303366, 11.737172), 1e-6
      structure.atoms[296].pos.should be_close vec3(6.664049, 11.614183, 12.961486), 1e-6

      structure.cell?.should_not be_nil
      structure.cell.size.should eq [15, 15, 15]
      structure.cell.angles.should eq({90, 90, 90})

      structure = reader.read_entry 2
      structure.metadata["time"]?.should eq 2
      structure.atoms[0].pos.should be_close vec3(0.29909524, 8.31003, 11.721462), 1e-6
      structure.atoms[296].pos.should be_close vec3(6.797599, 11.50882, 12.704233), 1e-6
    end
  end

  it "sets cell to nil if missing" do
    structure = fake_structure size: 401
    Chem::DCD::Reader.open(spec_file("nopbc.dcd"), structure) do |reader|
      structure = reader.read_entry
      structure.cell?.should be_nil
    end
  end

  it "reads an orthorhombic cell" do
    structure = fake_structure size: 364
    Chem::DCD::Reader.open(spec_file("withpbc.dcd"), structure) do |reader|
      structure = reader.read_entry
      structure.cell?.should_not be_nil
      structure.cell.size.should eq [100, 100, 100]
      structure.cell.angles.should eq({90, 90, 90})
    end
  end

  it "reads a triclinic cell" do
    structure = fake_structure size: 13
    Chem::DCD::Reader.open(spec_file("triclinic-octane-direct.dcd"), structure) do |reader|
      reader.n_entries.should eq 10

      structure = reader.read_entry
      structure.cell?.should_not be_nil
      structure.cell.size.should be_close [4.109898, 4.707060, 10.993230], 1e-6
      structure.cell.angles.should be_close({105.571273, 73.688987, 125.133354}, 1e-6)
    end
  end

  it "reads a triclinic cell with cosine angles" do
    structure = fake_structure size: 13
    Chem::DCD::Reader.open(spec_file("triclinic-octane-cos.dcd"), structure) do |reader|
      reader.n_entries.should eq 10

      structure = reader.read_entry
      structure.cell?.should_not be_nil
      structure.cell.size.should be_close [4.109898, 4.707060, 10.993230], 1e-6
      structure.cell.angles.should be_close({105.571274, 73.688985, 125.133355}, 1e-6)
    end
  end

  it "reads cell vectors" do
    structure = fake_structure size: 13
    Chem::DCD::Reader.open(spec_file("triclinic-octane-vectors.dcd"), structure) do |reader|
      reader.n_entries.should eq 10

      structure = reader.read_entry
      structure.cell?.should_not be_nil
      structure.cell.size.should be_close [4.1594858, 4.749700, 11.000093], 1e-6
      structure.cell.angles.should be_close({94.804658, 84.486392, 105.108346}, 1e-6)
    end
  end

  it "reads a cell from NAMD" do
    structure = fake_structure size: 9999
    Chem::DCD::Reader.open(spec_file("triclinic-namd.dcd"), structure) do |reader|
      reader.n_entries.should eq 1

      structure = reader.read_entry
      structure.cell?.should_not be_nil
      structure.cell.size.should be_close [85.440037, 89.442719, 85.440037], 1e-6
      structure.cell.angles.should be_close({65.244990, 70.806038, 71.696265}, 1e-6)
      structure.cell.volume.should be_close 548000, 1e-6
    end
  end

  it "reads a 4D DCD" do
    structure = fake_structure size: 27
    Chem::DCD::Reader.open(spec_file("4d-dynamic.dcd"), structure) do |reader|
      reader.n_entries.should eq 5

      structure = reader.read_entry
      structure.cell?.should be_nil
      structure.atoms[5].pos.should be_close vec3(-1.5822195, 0.6511365, 1.3911803), 1e-6
      structure.atoms[15].pos.should be_close vec3(2.2381972, -0.5173331, -0.4879273), 1e-6

      structure = reader.read_entry 3
      structure.cell?.should be_nil
      structure.atoms[5].pos.should be_close vec3(-1.5833939, 0.70485264, 1.3606575), 1e-6
      structure.atoms[15].pos.should be_close vec3(2.230041, -0.5253474, -0.50111574), 1e-6
    end
  end

  it "reads fixed atoms" do
    structure = fake_structure size: 12
    Chem::DCD::Reader.open(spec_file("fixed-atoms.dcd"), structure) do |reader|
      reader.n_entries.should eq 10

      structure = reader.read_entry
      structure.cell?.should be_nil
      structure.atoms[2].pos.should be_close vec3(-1.0220516, -1.0135641, 0), 1e-6
      structure.atoms[10].pos.should be_close vec3(1.820057, -1.3015488, 10), 1e-6

      structure = reader.read_entry
      structure.cell?.should be_nil
      structure.atoms[2].pos.should be_close vec3(-1.0220516, -1.0135641, 0), 1e-6
      structure.atoms[10].pos.should be_close vec3(1.8200468, -1.3015325, 10), 1e-6

      structure = reader.read_entry 5
      structure.cell?.should be_nil
      structure.atoms[2].pos.should be_close vec3(-1.0220516, -1.0135641, 0), 1e-6
      structure.atoms[10].pos.should be_close vec3(1.8199368, -1.3013588, 10), 1e-6
    end
  end

  it "reads big endian" do
    structure = fake_structure size: 7
    Chem::DCD::Reader.open(spec_file("mrmd_h2so4-32bit-be.dcd"), structure) do |reader|
      reader.n_entries.should eq 50

      structure = reader.read_entry 23
      structure.cell?.should be_nil
      structure.atoms[2].pos.should be_close vec3(0.6486294, 0.062248673, -1.5570515), 1e-6
      structure.atoms[4].pos.should be_close vec3(-1.3111109, 0.35563222, 0.9946163), 1e-6
    end
  end

  it "reads 64-bit markers" do
    structure = fake_structure size: 7
    Chem::DCD::Reader.open(spec_file("mrmd_h2so4-64bit-le.dcd"), structure) do |reader|
      reader.n_entries.should eq 50

      structure = reader.read_entry 23
      structure.cell?.should be_nil
      structure.atoms[2].pos.should be_close vec3(0.6486294, 0.062248673, -1.5570515), 1e-6
      structure.atoms[4].pos.should be_close vec3(-1.3111109, 0.35563222, 0.9946163), 1e-6
    end
  end

  it "reads 64-bit markers (big endian)" do
    structure = fake_structure size: 7
    Chem::DCD::Reader.open(spec_file("mrmd_h2so4-64bit-be.dcd"), structure) do |reader|
      reader.n_entries.should eq 50

      structure = reader.read_entry 23
      structure.cell?.should be_nil
      structure.atoms[2].pos.should be_close vec3(0.6486294, 0.062248673, -1.5570515), 1e-6
      structure.atoms[4].pos.should be_close vec3(-1.3111109, 0.35563222, 0.9946163), 1e-6
    end
  end
end

private def fake_structure(*, size : Int) : Chem::Structure
  Chem::Structure.build do |builder|
    size.times { builder.atom vec3(0, 0, 0) }
  end
end
