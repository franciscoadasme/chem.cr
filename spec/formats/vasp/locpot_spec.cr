require "../../spec_helper"

describe Chem::VASP::Locpot do
  it "parses a LOCPOT" do
    grid = Chem::Spatial::Grid.from_locpot spec_file("vasp/LOCPOT")
    grid.source_file.should eq Path[spec_file("vasp/LOCPOT")].expand
    grid.dim.should eq({32, 32, 32})
    grid.bounds.should be_close Chem::Spatial::Parallelepiped.new(
      vec3(2.969072, -0.000523, -0.000907),
      vec3(-0.987305, 2.800110, 0.000907),
      vec3(-0.987305, -1.402326, 2.423654)
    ), 1e-6
    grid[0, 0, 0].should eq -46.16312251
    grid[0, 5, 11].should eq -8.1037443195
    grid[7, 31, 0].should eq -17.403441349
    grid[17, 20, 11].should eq -4.028097687
    grid[31, 31, 31].should eq -45.337774769
  end

  it "parses a LOCPOT header" do
    info = Chem::Spatial::Grid::Info.from_locpot spec_file("vasp/LOCPOT")
    info.bounds.should be_close Chem::Spatial::Parallelepiped.new(
      vec3(2.969072, -0.000523, -0.000907),
      vec3(-0.987305, 2.800110, 0.000907),
      vec3(-0.987305, -1.402326, 2.423654),
    ), 1e-6
    info.dim.should eq({32, 32, 32})
  end

  it "parses structure" do
    reader = Chem::VASP::Locpot::Reader.new spec_file("vasp/LOCPOT")
    structure = reader.read_attached
    structure.should be_a Chem::Structure
    structure.source_file.should eq Path[spec_file("vasp/LOCPOT")].expand
    structure.atoms.size.should eq 2
    structure.atoms.map(&.element.symbol).should eq %w(Li C)
    structure.atoms[0].pos.should eq [0, 0, 0]
    structure.atoms[1].pos.should be_close [0.497, 0.699, 1.212], 1e-3

    structure.should be reader.read_attached
  end

  it "writes a LOCPOT" do
    structure = Chem::Structure.build do
      title "NaCl-O-NaCl"
      cell 5, 10, 20
      atom :Cl, vec3(30, 15, 10)
      atom :Na, vec3(10, 5, 5)
      atom :O, vec3(30, 15, 9)
      atom :Na, vec3(10, 10, 12.5)
      atom :Cl, vec3(20, 10, 10)
    end

    grid = make_grid({3, 3, 3}, {5, 10, 20}) { |i, j, k| i * 100 + j * 10 + k }
    grid.to_locpot(structure).should eq <<-EOF
      NaCl-O-NaCl
         1.00000000000000
           5.0000000000000000    0.0000000000000000    0.0000000000000000
           0.0000000000000000   10.0000000000000000    0.0000000000000000
           0.0000000000000000    0.0000000000000000   20.0000000000000000
         Cl   Na   O 
           2     2     1
      Cartesian
         30.0000000000000000   15.0000000000000000   10.0000000000000000
         20.0000000000000000   10.0000000000000000   10.0000000000000000
         10.0000000000000000    5.0000000000000000    5.0000000000000000
         10.0000000000000000   10.0000000000000000   12.5000000000000000
         30.0000000000000000   15.0000000000000000    9.0000000000000000

          3    3    3
       0.00000000000E+00 0.10000000000E+03 0.20000000000E+03 0.10000000000E+02 0.11000000000E+03
       0.21000000000E+03 0.20000000000E+02 0.12000000000E+03 0.22000000000E+03 0.10000000000E+01
       0.10100000000E+03 0.20100000000E+03 0.11000000000E+02 0.11100000000E+03 0.21100000000E+03
       0.21000000000E+02 0.12100000000E+03 0.22100000000E+03 0.20000000000E+01 0.10200000000E+03
       0.20200000000E+03 0.12000000000E+02 0.11200000000E+03 0.21200000000E+03 0.22000000000E+02
       0.12200000000E+03 0.22200000000E+03

      EOF
  end

  it "fails when writing a LOCPOT with a non-periodic structure" do
    grid = make_grid({3, 3, 3}, {1, 2, 3})
    expect_raises Chem::Spatial::NotPeriodicError do
      grid.to_locpot Chem::Structure.new
    end
  end

  it "fails when cell and bounds are incompatible" do
    structure = Chem::Structure.build { cell 10, 20, 30 }
    expect_raises ArgumentError, "Incompatible structure and grid" do
      make_grid({3, 3, 3}, {20, 20, 20}).to_locpot structure
    end
  end
end
