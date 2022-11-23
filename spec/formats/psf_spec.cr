require "../spec_helper.cr"

describe Chem::PSF::Reader do
  it "parses a PSF file" do
    top = Chem::Topology.from_psf spec_file("5yok_initial.psf")
    top.atoms.size.should eq 819
    top.bonds.size.should eq 804
    top.angles.size.should eq 1416
    top.dihedrals.size.should eq 1938
    top.impropers.size.should eq 140

    top.chains.size.should eq 19
    top.residues.join(&.code).should eq(
      "RLDTGADDTVKIGGIGGFLTPVIGRLDTGADDTVKIGGIGGFLTPVIGX")
    top.chains.map(&.residues.join(&.code)).should eq %w(
      R L DTGADDTV K IGGIGGF L TPV I G R L DTGADDTV K IGGIGGF L TPV I G X)

    atom = top.atoms[753]?.should_not be_nil
    atom.serial.should eq 754
    atom.name.should eq "CG"
    atom.typename.should eq "C136"
    atom.residue.number.should eq 81
    atom.residue.name.should eq "PRO"
    atom.chain.id.should eq 'P'
    atom.partial_charge.should eq -0.12
    atom.mass.should eq 12.011
    atom.bonded_atoms.map(&.serial).should eq [751, 746, 755, 756]

    top.angles[2].atoms.map(&.serial).should eq({2, 1, 4})
    top.dihedrals[6].atoms.map(&.serial).should eq({4, 1, 5, 7})
    top.impropers[15].atoms.map(&.serial).should eq({80, 90, 91, 92})
  end

  it "parses PSF with non-multiple number of records (#178)" do
    top = Chem::Topology.from_psf spec_file("DTD.psf")
    top.atoms.size.should eq 16
    top.bonds.size.should eq 16
    top.angles.size.should eq 28
    top.dihedrals.size.should eq 40
    top.impropers.size.should eq 8
  end

  it "parses PSF with extended format (#190)" do
    top = Chem::Topology.from_psf spec_file("N4I.psf")
    top.atoms.size.should eq 67
    top.bonds.size.should eq 70
    top.angles.size.should eq 124
    top.dihedrals.size.should eq 187
    top.impropers.size.should eq 20

    atom = top.atoms[-1]
    atom.serial.should eq 67
    atom.residue.number.should eq 1
    atom.residue.name.should eq "N4I"
    atom.name.should eq "H28"
    atom.typename.should eq "HALT"
    atom.partial_charge.should eq 0.1555
    atom.mass.should eq 1.008
  end
end
