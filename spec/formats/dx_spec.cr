require "../spec_helper"

describe Chem::DX::Reader do
  it "parses a DX file" do
    grid = Grid.from_dx spec_file("simple.dx")
    grid.source_file.should eq Path[spec_file("simple.dx")].expand
    grid.dim.should eq({2, 3, 3})
    grid.bounds.should eq Bounds.new(Vec3[0.5, 0.3, 1], Size[10, 40, 20])
    grid.to_a.should eq [
      0, 1, 2, 10, 11, 12, 20, 21, 22, 100, 101, 102, 110, 111, 112, 120, 121, 122,
    ]
  end

  it "parses a DX header" do
    info = Grid::Info.from_dx spec_file("header.dx")
    info.bounds.should eq Bounds.new(
      Vec3[0.5, 0.3, 1],
      Vec3[10, 0, 0],
      Vec3[10, 40, 0],
      Vec3[16, 10, 20]
    )
    info.dim.should eq({2, 3, 3})
  end
end

describe Chem::DX::Writer do
  it "writes a grid" do
    grid = make_grid(3, 2, 2, Bounds.new(Vec3[0.5, 0.3, 1], Size[20, 20, 10])) do |i, j, k|
      i * 100 + j * 10 + k
    end
    grid.to_dx.should eq <<-EOS
      object 1 class gridpositions counts 3 2 2
      origin   0.500   0.300   1.000
      delta   10.000   0.000   0.000
      delta    0.000  20.000   0.000
      delta    0.000   0.000  10.000
      object 2 class gridconnections counts 3 2 2
      object 3 class array type double rank 0 items 12 data follows
            0.00000000      1.00000000     10.00000000
           11.00000000    100.00000000    101.00000000
          110.00000000    111.00000000    200.00000000
          201.00000000    210.00000000    211.00000000\n
      EOS
  end
end
