require "../spec_helper"

describe Chem::Spatial do
  describe "#rmsd" do
    it "computes the rmsd in-place" do
      s = Array(Chem::Structure).read spec_file("E20_conformers.mol2")
      Chem::Spatial.rmsd(s[1], s[0]).should be_close 7.933736, 1e-6
      Chem::Spatial.rmsd(s[2], s[0]).should be_close 2.607424, 1e-6
      Chem::Spatial.rmsd(s[3], s[0]).should be_close 8.177316, 1e-6
      Chem::Spatial.rmsd(s[4], s[0]).should be_close 1.815176, 1e-6
    end

    it "computes the rmsd in-place with weights" do
      s = Array(Chem::Structure).read spec_file("E20_conformers.mol2")
      weights = s[0].atoms.map &.mass
      Chem::Spatial.rmsd(s[1], s[0], weights).should be_close 8.187659, 1e-6
      Chem::Spatial.rmsd(s[2], s[0], weights).should be_close 2.265467, 1e-6
      Chem::Spatial.rmsd(s[3], s[0], weights).should be_close 7.955341, 1e-6
      Chem::Spatial.rmsd(s[4], s[0], weights).should be_close 1.510461, 1e-6
    end

    it "computes the minimum rmsd" do
      s = Array(Chem::Structure).read spec_file("E20_conformers.mol2")
      Chem::Spatial.rmsd(s[1], s[0], minimize: true).should be_close 3.463298, 1e-6
      Chem::Spatial.rmsd(s[2], s[0], minimize: true).should be_close 1.818679, 1e-6
      Chem::Spatial.rmsd(s[3], s[0], minimize: true).should be_close 3.845655, 1e-6
      Chem::Spatial.rmsd(s[4], s[0], minimize: true).should be_close 1.475276, 1e-6
    end

    it "computes the minimum rmsd with weights" do
      s = Array(Chem::Structure).read spec_file("E20_conformers.mol2")
      weights = s[0].atoms.map &.mass
      Chem::Spatial.rmsd(s[1], s[0], weights, minimize: true).should be_close 2.811033, 1e-6
      # Chem::Spatial.rmsd(s[2], s[0], weights, minimize: true).should be_close 1.358219, 1e-6
      # Chem::Spatial.rmsd(s[3], s[0], weights, minimize: true).should be_close 3.067433, 1e-6
      # Chem::Spatial.rmsd(s[4], s[0], weights, minimize: true).should be_close 1.084173, 1e-6
    end
  end
end
