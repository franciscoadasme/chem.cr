require "../spec_helper"

describe Chem::PSF do
  it "parses a PSF file" do
    path = spec_file("5yok_initial.psf")
    structure = Chem::PSF.read path
    structure.source_file.should eq Path[path].expand
    structure.atoms.size.should eq 819
    structure.bonds.size.should eq 804

    structure.chains.size.should eq 19
    structure.residues.join(&.code).should eq(
      "RLDTGADDTVKIGGIGGFLTPVIGRLDTGADDTVKIGGIGGFLTPVIGX")
    structure.chains.map(&.residues.join(&.code)).should eq %w(
      R L DTGADDTV K IGGIGGF L TPV I G R L DTGADDTV K IGGIGGF L TPV I G X)

    atom = structure.atoms[753]?.should_not be_nil
    atom.number.should eq 754
    atom.name.should eq "CG"
    atom.typename.should eq "C136"
    atom.residue.number.should eq 81
    atom.residue.name.should eq "PRO"
    atom.chain.id.should eq 'P'
    atom.partial_charge.should eq -0.12
    atom.mass.should eq 12.011
    atom.bonded_atoms.map(&.number).should eq [751, 746, 755, 756]
  end

  it "parses PSF with non-multiple number of records (#178)" do
    structure = Chem::PSF.read spec_file("DTD.psf")
    structure.atoms.size.should eq 16
    structure.bonds.size.should eq 16
  end

  it "parses PSF with extended format (#190)" do
    structure = Chem::PSF.read spec_file("N4I.psf")
    structure.atoms.size.should eq 67
    structure.bonds.size.should eq 70

    atom = structure.atoms[-1]
    atom.number.should eq 67
    atom.residue.number.should eq 1
    atom.residue.name.should eq "N4I"
    atom.name.should eq "H28"
    atom.typename.should eq "HALT"
    atom.partial_charge.should eq 0.1555
    atom.mass.should eq 1.008
  end
end
