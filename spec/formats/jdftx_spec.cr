require "../spec_helper"

describe Chem::JDFTx::Reader do
  it "parses a JDFTx file" do
    path = spec_file("polyala-val.ionpos")
    structure = Chem::Structure.from_jdftx path, guess_bonds: true, guess_names: true

    structure.residues.size.should eq 6
    structure.residues.map(&.name).should eq %w(VAL ALA ALA ALA ALA ALA)
    structure.dig('A', 1, "HG13").pos.should be_close vec3(-3.632, 1.758, 1.855), 1e-3

    structure.cell.basisvec.should be_close [
      vec3(21.023, 0, 0),
      vec3(0, 21.056, 0),
      vec3(0, 0, 21.162),
    ], 1e-3
  end

  it "parses a split JDFTx file" do
    path = spec_file("ff2d.ionpos")
    structure = Chem::Structure.from_jdftx path
    structure.atoms[5].pos.should be_close vec3(-9.997, -3.330, 3.142), 1e-3

    structure.guess_bonds
    structure.guess_formal_charges
    structure.guess_names
    structure.residues.size.should eq 36
    structure.residues.map(&.name).uniq.should eq %w(PHE)

    structure.cell.basisvec.should be_close [
      vec3(23.84396309, 0.00112639, 0.00055391),
      vec3(-11.92104721, 20.67853790, -0.00008092),
      vec3(-0.00082321, -0.00033590, 35.43662857),
    ], 1e-8
  end
end

describe Chem::JDFTx::Writer do
  it "writes a JDFTx file" do
    path = spec_file("polyala-val.ionpos")
    expected = reduced_cell_prec File.read(path)
    actual = reduced_cell_prec Chem::Structure.read(path).to_jdftx
    actual.should eq expected
  end

  it "writes a split JDFTx file" do
    path = Path[spec_file("ff2d.ionpos")]
    tmp = File.tempfile(".ionpos") do |io|
      Chem::Structure.read(path).to_jdftx io, single_file: false
    end

    File.read(tmp.path).should eq File.read(path)
    expected = reduced_cell_prec File.read(path.with_ext(".lattice"))
    actual = reduced_cell_prec File.read(Path[tmp.path].with_ext(".lattice"))
    actual.should eq expected
  ensure
    tmp.try &.delete
  end

  it "writes fractional coordinates" do
    expected = File.read spec_file("polyala-val_f.ionpos")
    path = spec_file("polyala-val.ionpos")
    actual = Chem::Structure.read(path).to_jdftx fractional: true
    reduced_cell_prec(actual).should eq reduced_cell_prec(expected)
  end
end

private def reduced_cell_prec(str : String)
  str.gsub(/\.(\d{3})\d{12}/, ".\\1000000000000")
end
