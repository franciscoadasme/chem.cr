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

  describe "#inspect" do
    it "returns a delimited string representation" do
      Chem::PeriodicTable::Br.inspect.should eq "<Element Br(35)>"
    end
  end
end
