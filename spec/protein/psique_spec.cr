require "../spec_helper"

describe Chem::Protein::PSIQUE do
  it "assigns secondary structure (1cbn)" do
    st = load_file "1cbn.pdb"
    Chem::Protein::PSIQUE.assign st
    actual = st.residues.select(&.has_backbone?).map(&.sec.code).join
    actual.should eq "0EEE00HHHHHHHHHHGGG000HHHHHHHH00EEE000000GGGG0"
  end

  it "assigns secondary structure (1dpo)" do
    st = load_file "1dpo.pdb"
    Chem::Protein::PSIQUE.assign st
    expected = <<-EOS.gsub(/\s+/, "")
      00000PPPP000000EEEE00000EEEE00000EEEEEGGG0000EEEEE000000000000EEEE
      E0EEEEE00000000000EEEEE0000000000PPPPPPP00PPP000EEEEEE000000000000
      00EEEEEEEEE00HHHHHH00000000EEEEEE00000000000000EEEE00000EE00000000
      0000PPPPP0GGGGHHHHHHHHH00
      EOS
    st.residues.select(&.has_backbone?).map(&.sec.code).join.should eq expected
  end
end
