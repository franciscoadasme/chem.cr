require "../spec_helper.cr"

describe Chem::PSF::Reader do
  it "parses a PSF file" do
    structure = Chem::Structure.from_psf(spec_file("5yok_initial.psf"))
    structure.atoms.size.should eq 819
    structure.bonds.size.should eq 804
    structure.angles.size.should eq 1416
    structure.dihedrals.size.should eq 1938
    structure.impropers.size.should eq 140

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

    structure.angles[2].atoms.map(&.number).should eq({2, 1, 4})
    structure.dihedrals[6].atoms.map(&.number).should eq({4, 1, 5, 7})
    structure.impropers[15].atoms.map(&.number).should eq({80, 90, 91, 92})
  end

  it "parses PSF with non-multiple number of records (#178)" do
    structure = Chem::Structure.from_psf(spec_file("DTD.psf"))
    structure.atoms.size.should eq 16
    structure.bonds.size.should eq 16
    structure.angles.size.should eq 28
    structure.dihedrals.size.should eq 40
    structure.impropers.size.should eq 8
  end

  it "parses PSF with extended format (#190)" do
    structure = Chem::Structure.from_psf(spec_file("N4I.psf"))
    structure.atoms.size.should eq 67
    structure.bonds.size.should eq 70
    structure.angles.size.should eq 124
    structure.dihedrals.size.should eq 187
    structure.impropers.size.should eq 20

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
