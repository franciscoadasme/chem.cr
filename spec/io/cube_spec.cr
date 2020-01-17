require "../spec_helper"

describe Chem::Cube::Parser do
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
    expect_raises IO::Error, "not supported" do
      Grid.from_cube io
    end
  end
end

describe Chem::Cube::Writer do
  it "writes a grid" do
    structure = Chem::Structure.build do
      atom :Cu, V[2.317035, 3.50954, -0.79557], partial_charge: 29.0
      atom :O, V[3.517299, 6.882575, -1.794666], partial_charge: 8.0
      atom :H, V[3.658572, 8.310089, -0.667807], partial_charge: 1.0
      atom :H, V[3.55781, 7.487509, -3.515277], partial_charge: 1.0
      atom :O, V[0.522854, 0.396282, 0.154812], partial_charge: 8.0
      atom :H, V[-0.123518, 0.047338, 1.824539], partial_charge: 1.0
      atom :H, V[-0.230385, -0.775379, -1.022862], partial_charge: 1.0
      atom :O, V[6.060706, 1.880214, -0.48988], partial_charge: 8.0
      atom :H, V[6.473038, 0.17068, -0.010227], partial_charge: 1.0
      atom :H, V[7.644308, 2.732568, -0.787247], partial_charge: 1.0
      atom :O, V[2.14017, 4.657838, 2.815361], partial_charge: 8.0
      atom :O, V[1.905012, 2.624361, -4.461808], partial_charge: 8.0
      atom :H, V[0.470734, 2.905126, -5.555472], partial_charge: 1.0
      atom :H, V[3.187141, 1.724891, -5.399287], partial_charge: 1.0
      atom :H, V[3.511551, 4.405199, 3.993241], partial_charge: 1.0
      atom :H, V[0.794769, 5.548665, 3.668909], partial_charge: 1.0
    end

    content = File.read "spec/data/cube/20.cube"
    io = IO::Memory.new content
    Grid.from_cube(io).to_cube(structure).should eq content
  end
end
