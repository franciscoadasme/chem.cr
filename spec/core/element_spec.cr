require "../spec_helper"

describe Chem::Element do
  it "holds correct information" do
    ele = Chem::PeriodicTable::C
    ele.atomic_number.should eq 6
    ele.name.should eq "Carbon"
    ele.symbol.should eq "C"
    ele.mass.should eq 12.0107
    ele.covalent_radius.should eq 0.76
    ele.vdw_radius.should eq 1.77
    ele.valence_electrons.should eq 4
    ele.valence.should eq 4
  end

  describe "#===" do
    it "tells if atom matches element" do
      atom = Chem::Structure.build { atom "NG1", vec3(0, 0, 0) }.atoms[0]

      (Chem::PeriodicTable::N === atom).should be_true
      (Chem::PeriodicTable::O === atom).should be_false
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      Chem::PeriodicTable::Br.to_s.should eq "<Element Br>"
    end
  end

  describe "#target_electrons" do
    it "returns the number of electrons" do
      Chem::PeriodicTable::H.target_electrons(1).should eq 2
      Chem::PeriodicTable::He.target_electrons(1).should eq 2
      Chem::PeriodicTable::C.target_electrons(4).should eq 8
      Chem::PeriodicTable::N.target_electrons(3).should eq 8
      Chem::PeriodicTable::N.target_electrons(4).should eq 8
      Chem::PeriodicTable::O.target_electrons(1).should eq 8
      Chem::PeriodicTable::O.target_electrons(2).should eq 8
      Chem::PeriodicTable::O.target_electrons(3).should eq 8

      Chem::PeriodicTable::S.target_electrons(2).should eq 8
      Chem::PeriodicTable::S.target_electrons(3).should eq 8
      Chem::PeriodicTable::S.target_electrons(4).should eq 10
      Chem::PeriodicTable::S.target_electrons(5).should eq 12
      Chem::PeriodicTable::S.target_electrons(6).should eq 12

      Chem::PeriodicTable::P.target_electrons(2).should eq 8
      Chem::PeriodicTable::P.target_electrons(3).should eq 8
      Chem::PeriodicTable::P.target_electrons(4).should eq 8
      Chem::PeriodicTable::P.target_electrons(5).should eq 10
      Chem::PeriodicTable::P.target_electrons(6).should eq 12
    end
  end
end
