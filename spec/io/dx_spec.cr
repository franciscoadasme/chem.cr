require "../spec_helper"

describe Chem::DX::Parser do
  it "parses a DX file" do
    io = IO::Memory.new <<-EOS
      # comment line 1
      # comment line 2
      # comment line 3
      object 1 class gridpositions counts 2 3 3
      origin   0.500   0.300   1.000
      delta   10.000   0.000   0.000
      delta    0.000  20.000   0.000
      delta    0.000   0.000  10.000
      object 2 class gridconnections counts 2 3 3
      object 3 class array type double rank 0 items 18 data follows
            0.00000000      1.00000000      2.00000000
           10.00000000     11.00000000     12.00000000
           20.00000000     21.00000000     22.00000000
          100.00000000    101.00000000    102.00000000
          110.00000000    111.00000000    112.00000000
          120.00000000    121.00000000    122.00000000\n
      EOS

    grid = Grid.from_dx io
    grid.dim.should eq({2, 3, 3})
    grid.bounds.should eq Bounds.new(V[0.5, 0.3, 1], S[10, 40, 20])
    grid.to_a.should eq [
      0, 1, 2, 10, 11, 12, 20, 21, 22, 100, 101, 102, 110, 111, 112, 120, 121, 122,
    ]
  end

  it "parses a DX header" do
    io = IO::Memory.new <<-EOS
      # comment line 1
      # comment line 2
      # comment line 3
      object 1 class gridpositions counts 2 3 3
      origin   0.500   0.300   1.000
      delta   10.000   0.000   0.000
      delta    5.000  20.000   0.000
      delta    8.000   5.000  10.000
      object 2 class gridconnections counts 2 3 3
      object 3 class array type double rank 0 items 18 data follows
            0.00000000      1.00000000      2.00000000
           10.00000000     11.00000000     12.00000000
           20.00000000     21.00000000     22.00000000
          100.00000000    101.00000000    102.00000000
          110.00000000    111.00000000    112.00000000
          120.00000000    121.00000000    122.00000000\n
      EOS
    info = Grid.info io, :dx
    info.bounds.should eq Bounds.new(
      V[0.5, 0.3, 1],
      V[10, 0, 0],
      V[10, 40, 0],
      V[16, 10, 20]
    )
    info.dim.should eq({2, 3, 3})
  end
end

describe Chem::DX::Writer do
  it "writes a grid" do
    grid = make_grid(3, 2, 2, Bounds.new(V[0.5, 0.3, 1], S[20, 20, 10])) do |i, j, k|
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
