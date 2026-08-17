require "../spec_helper"

private def gopenmol_io(
  dim : {Int32, Int32, Int32},
  vmin : Chem::Spatial::Vec3,
  vmax : Chem::Spatial::Vec3,
  values : Indexable(Number),
  byte_format : IO::ByteFormat = IO::ByteFormat::LittleEndian,
  rank : Int32 = 3,
  surface : Int32 = 2,
) : IO::Memory
  io = IO::Memory.new
  io.write_bytes rank, byte_format
  io.write_bytes surface, byte_format
  io.write_bytes dim[2], byte_format
  io.write_bytes dim[1], byte_format
  io.write_bytes dim[0], byte_format
  io.write_bytes vmin.z.to_f32, byte_format
  io.write_bytes vmax.z.to_f32, byte_format
  io.write_bytes vmin.y.to_f32, byte_format
  io.write_bytes vmax.y.to_f32, byte_format
  io.write_bytes vmin.x.to_f32, byte_format
  io.write_bytes vmax.x.to_f32, byte_format
  values.each { |value| io.write_bytes value.to_f32, byte_format }
  io.rewind
  io
end

describe Chem::GOpenMol do
  describe ".read" do
    it "reads a gOpenMol binary grid" do
      # file order is X fastest, then Y, then Z
      io = gopenmol_io(
        {2, 2, 2},
        vec3(0, 2, -1),
        vec3(1, 4, 1),
        [1, 2, 3, 4, 5, 6, 7, 8],
      )
      grid = Chem::GOpenMol.read io
      grid.dim.should eq({2, 2, 2})
      grid.origin.should be_close [0, 2.bohrs, -1.bohrs], 1e-6
      grid.bounds.size.should be_close [1.bohrs, 2.bohrs, 2.bohrs], 1e-6
      grid[0, 0, 0].should eq 1
      grid[1, 0, 0].should eq 2
      grid[0, 1, 0].should eq 3
      grid[1, 1, 0].should eq 4
      grid[0, 0, 1].should eq 5
      grid[1, 0, 1].should eq 6
      grid[0, 1, 1].should eq 7
      grid[1, 1, 1].should eq 8
    end

    it "reads a gOpenMol binary file" do
      # Taken from MDAnalysis's GridDataFormats test suite.
      path = spec_file("nachr_m2_water.plt")
      grid = Chem::GOpenMol.read path
      grid.source_file.should eq Path[path].expand
      grid.size.should eq 165048
      grid.dim.should eq({46, 46, 78})
      grid.origin.should be_close [0.0995016.bohrs, 0.0995016.bohrs, 0.0919984.bohrs], 1e-6
      grid.bounds.size.should be_close [46.bohrs, 46.bohrs, 78.bohrs], 1e-5
      grid.step(20, 20, 30).to_a.should be_close [
        1.02196848, 0.0, 0.88893718,
        0.99051529, 0.0, 0.95906246,
        0.96112466, 0.0, 0.88996845,
        0.97247058, 0.0, 0.91574967,
        1.00237465, 1.34423399, 0.87810922,
        0.97917157, 0.0, 0.84717268,
        0.99103099, 0.0, 0.86521846,
        0.96421844, 0.0, 0.0,
        0.98432779, 0.0, 0.8817184,
      ], 1e-8
      grid.mean.should be_close 0.5403224581733577, 1e-12
    end

    it "reads a big-endian file" do
      io = gopenmol_io(
        {2, 1, 3},
        vec3(0, 0, 0),
        vec3(1, 0, 2),
        [10, 20, 30, 40, 50, 60],
        byte_format: IO::ByteFormat::BigEndian,
      )
      grid = Chem::GOpenMol.read io
      grid.dim.should eq({2, 1, 3})
      grid[0, 0, 0].should eq 10
      grid[1, 0, 0].should eq 20
      grid[0, 0, 1].should eq 30
      grid[1, 0, 1].should eq 40
      grid[0, 0, 2].should eq 50
      grid[1, 0, 2].should eq 60
    end

    it "sets source_file when reading from a path" do
      io = gopenmol_io({1, 1, 1}, vec3(0, 0, 0), vec3(0, 0, 0), [1.5])
      File.tempfile("grid", ".plt") do |file|
        file.write io.to_slice
        file.flush
        grid = Chem::GOpenMol.read file.path
        grid.source_file.should eq Path[file.path].expand
        grid[0, 0, 0].should eq 1.5
      end
    end

    it "fails when rank is not 3" do
      io = gopenmol_io({1, 1, 1}, vec3(0, 0, 0), vec3(0, 0, 0), [0], rank: 4)
      expect_raises Chem::ParseException, "rank is 4, expected 3" do
        Chem::GOpenMol.read io
      end
    end
  end

  describe ".read_info" do
    it "reads the header without the data" do
      io = gopenmol_io(
        {4, 5, 6},
        vec3(-3, 0, 2),
        vec3(1, 8, 5),
        [] of Float64,
      )
      info = Chem::GOpenMol.read_info io
      info.dim.should eq({4, 5, 6})
      info.bounds.origin.should be_close [(-3).bohrs, 0, 2.bohrs], 1e-6
      info.bounds.size.should be_close [4.bohrs, 8.bohrs, 3.bohrs], 1e-6
    end
  end

  describe ".write" do
    it "writes a grid" do
      bounds = Chem::Spatial::Parallelepiped.new(
        vec3(0, 2.bohrs, (-1).bohrs),
        vec3(1.bohrs, 4.bohrs, 1.bohrs),
      )
      grid = make_grid({2, 2, 2}, bounds) { |i, j, k| i + 2 * j + 4 * k }
      io = IO::Memory.new
      Chem::GOpenMol.write io, grid
      io.rewind
      Chem::GOpenMol.read(io).should eq grid
    end

    it "fails for a non-orthogonal grid" do
      bounds = Chem::Spatial::Parallelepiped.new(
        vec3(1, 0, 0),
        vec3(0.2, 1, 0),
        vec3(0, 0, 1),
      )
      grid = make_grid({2, 2, 2}, bounds)
      expect_raises ArgumentError, "only supports orthogonal grids" do
        Chem::GOpenMol.write IO::Memory.new, grid
      end
    end
  end
end
