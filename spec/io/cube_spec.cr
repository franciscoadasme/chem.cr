require "../spec_helper"

describe Chem::Cube::Reader do
  it "parses a cube file" do
    grid = Grid.from_cube "spec/data/cube/20.cube"
    grid.dim.should eq({20, 20, 20})
    grid.origin.should be_close V[-3.826155, -4.114553, -6.64407], 1e-6
    grid.bounds.size.should be_close S[12.184834, 12.859271, 13.117308], 1e-6
    grid[0, 0, 0].should eq 2.19227e-19
    grid[-1, -1, -1].should eq 7.36329e-22
    grid[1, 1, 5].should eq 1.61884e-14
  end

  it "parses a cube file header" do
    info = Grid.info "spec/data/cube/20.cube"
    info.dim.should eq({20, 20, 20})
    info.bounds.origin.should be_close V[-3.826155, -4.114553, -6.64407], 1e-6
    info.bounds.size.should be_close S[12.184834, 12.859271, 13.117308], 1e-6
  end

  it "parses a cube file header (non-orthogonal)" do
    io = IO::Memory.new <<-EOS
      Comment line 1
      Comment line 2
         3   -7.230385   -7.775379  -12.555472
        14    1.146929    0.000000    0.000000
        20    0.255354    1.061993    0.000000
        22    0.499640    0.190885    3.536519
        29   29.000000    2.317035    3.509540   -0.795570
         8    8.000000    3.517299    6.882575   -1.794666
         1    1.000000    3.658572    8.310089   -0.667807
         1    1.000000    3.557810    7.487509   -3.515277
      EOS
    info = Grid.info io, :cube
    info.dim.should eq({14, 20, 22})
    info.bounds.should be_close Bounds.new(
      V[-3.826155, -4.114553, -6.64407],
      V[8.497002, 0.0, 0.0],
      V[2.702550, 11.23965, 0.0],
      V[5.816758, 2.222264, 41.171796],
    ), 1e-6
  end

  it "fails when cube have multiple densities" do
    io = IO::Memory.new <<-EOF
      CPMD CUBE FILE.
      OUTER LOOP: X, MIDDLE LOOP: Y, INNER LOOP: Z
       -3    0.000000    0.000000    0.000000
        1    0.283459    0.000000    0.000000
        2    0.000000    0.283459    0.000000
        2    0.000000    0.000000    0.283459
        8    0.000000    5.570575    5.669178    5.593517
        1    0.000000    5.562867    5.669178    7.428055
        1    0.000000    7.340606    5.669178    5.111259
       -0.25568E-04  0.59213E-05  0.81068E-05  0.10868E-04
      EOF
    expect_raises ParseException, "not supported" do
      Grid.from_cube io
    end
  end
end

describe Chem::Cube::Writer do
  it "writes a grid" do
    structure = Chem::Structure.build do
      atom :Cu, V[1.22612212, 1.85716859, -0.42099751], partial_charge: 29.0
      atom :O, V[1.86127447, 3.64210184, -0.94969635], partial_charge: 8.0
      atom :H, V[1.93603293, 4.39750972, -0.35338825], partial_charge: 1.0
      atom :H, V[1.88271197, 3.96221913, -1.86020448], partial_charge: 1.0
      atom :O, V[0.27668242, 0.2097034, 0.08192298], partial_charge: 8.0
      atom :H, V[-0.06536291, 0.02505019, 0.96550446], partial_charge: 1.0
      atom :H, V[-0.12191449, -0.4103129, -0.54127526], partial_charge: 1.0
      atom :O, V[3.2071875, 0.9949664, -0.25923333], partial_charge: 8.0
      atom :H, V[3.42538419, 0.09031997, -0.0054119], partial_charge: 1.0
      atom :H, V[4.04519359, 1.44601271, -0.41659317], partial_charge: 1.0
      atom :O, V[1.13252919, 2.46482172, 1.48982488], partial_charge: 8.0
      atom :O, V[1.00808894, 1.38875203, -2.36108711], partial_charge: 8.0
      atom :H, V[0.24910171, 1.53732647, -2.93982918], partial_charge: 1.0
      atom :H, V[1.68656238, 0.91277301, -2.85717964], partial_charge: 1.0
      atom :H, V[1.85823276, 2.33113092, 2.11313213], partial_charge: 1.0
      atom :H, V[0.42057364, 2.93622707, 1.94150303], partial_charge: 1.0
    end

    content = File.read "spec/data/cube/20.cube"
    io = IO::Memory.new content
    Grid.from_cube(io).to_cube(structure).should eq content
  end
end
