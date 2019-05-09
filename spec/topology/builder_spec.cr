require "../spec_helper"

describe Chem::Topology::Builder do
  describe "#guess_bonds_from_geometry" do
    it "guesses bonds from geometry" do
      structure = Chem::Structure.read "spec/data/poscar/AlaIle--unwrapped.poscar"
      builder = Chem::Topology::Builder.new structure
      builder.guess_bonds_from_geometry

      atoms = structure.atoms
      n_bonds = [4, 4, 3, 4, 3, 4, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1,
                 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 3]
      atoms.each_with_index { |atom, i| atom.bonds.size.should eq n_bonds[i] }
      atoms[0].bonded_atoms.map(&.serial).sort!.should eq [2, 14, 15, 16]
      atoms[4].bonded_atoms.map(&.serial).sort!.should eq [4, 28, 30]
      atoms[4].bonds[atoms[27]].order.should eq 2
      atoms[4].bonds[atoms[29]].order.should eq 1
    end

    it "guesses bonds from geometry of a protein with charged termini and ions" do
      structure = Chem::Structure.read "spec/data/xyz/k2p_pore_b.xyz"
      builder = Chem::Topology::Builder.new structure
      builder.guess_bonds_from_geometry

      structure.bonds.size.should eq 644
      structure.bonds.sum(&.order).should eq 714
      structure.bonds.count(&.single?).should eq 574
      structure.bonds.count(&.double?).should eq 70

      structure.formal_charge.should eq 3
      structure.atoms.count(&.formal_charge.!=(0)).should eq 9

      # ions
      (638..641).each do |i|
        structure.atoms[i].valency.should eq 1
        structure.atoms[i].bonds.size.should eq 0
        structure.atoms[i].formal_charge.should eq 1
      end

      # n-ter
      structure.atoms[324].valency.should eq 3
      structure.atoms[324].bonds.size.should eq 4
      structure.atoms[324].formal_charge.should eq 1

      # c-ter
      structure.atoms[364].valency.should eq 2
      structure.atoms[364].formal_charge.should eq -1
      structure.atoms[365].valency.should eq 2
      structure.atoms[365].formal_charge.should eq 0

      structure.atoms[149].bonded_atoms.map(&.serial).should eq [145] # H near two Os

      # aromatic ring
      structure.atoms[427].bonds[structure.atoms[428]].order.should eq 2
      structure.atoms[428].bonds[structure.atoms[430]].order.should eq 1
      structure.atoms[430].bonds[structure.atoms[432]].order.should eq 2
      structure.atoms[432].bonds[structure.atoms[431]].order.should eq 1
      structure.atoms[431].bonds[structure.atoms[429]].order.should eq 2
      structure.atoms[429].bonds[structure.atoms[427]].order.should eq 1
    end

    it "guesses bonds from geometry having a sulfate ion" do
      structure = Chem::Structure.read "spec/data/xyz/sulbactam.xyz"
      builder = Chem::Topology::Builder.new structure
      builder.guess_bonds_from_geometry

      structure.bonds.size.should eq 27
      structure.bonds.sum(&.order).should eq 31
      structure.bonds.count(&.single?).should eq 23
      structure.bonds.count(&.double?).should eq 4

      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0

      structure.atoms[13].valency.should eq 2
      structure.atoms[13].bonded_atoms.map(&.serial).sort!.should eq [13, 26]
      structure.atoms[14].valency.should eq 2
      structure.atoms[14].bonded_atoms.map(&.serial).should eq [13]

      # sulfate ion
      structure.atoms[3].valency.should eq 6
      structure.atoms[3].bonded_atoms.map(&.serial).sort!.should eq [2, 5, 6, 7]
      structure.atoms[3].bonds[structure.atoms[1]].single?.should be_true
      structure.atoms[3].bonds[structure.atoms[4]].double?.should be_true
      structure.atoms[3].bonds[structure.atoms[5]].double?.should be_true
      structure.atoms[3].bonds[structure.atoms[6]].single?.should be_true
    end

    it "guesses bonds from geometry of a protein having sulfur" do
      structure = Chem::Structure.read "spec/data/xyz/acama.xyz"
      builder = Chem::Topology::Builder.new structure
      builder.guess_bonds_from_geometry

      structure.bonds.size.should eq 60
      structure.bonds.sum(&.order).should eq 65
      structure.bonds.count(&.single?).should eq 55
      structure.bonds.count(&.double?).should eq 5

      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0

      structure.atoms[15].valency.should eq 2
      structure.atoms[15].bonded_atoms.map(&.serial).should eq [15, 21]
      structure.atoms[15].bonds[structure.atoms[14]].single?.should be_true
      structure.atoms[15].bonds[structure.atoms[20]].single?.should be_true

      structure.atoms[37].valency.should eq 2
      structure.atoms[37].bonded_atoms.map(&.serial).should eq [37, 39]
      structure.atoms[37].bonds[structure.atoms[36]].single?.should be_true
      structure.atoms[37].bonds[structure.atoms[38]].single?.should be_true
    end
  end
end
