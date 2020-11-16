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
      00000PPPP000000EE000000000EE00000EEEEEGGG000EEEEEE000000000000EEEE
      E000PPP00000000000EEEE000000000000PPPPPP00PPPP0EEEEEEE00000000EE00
      00EEEE0PPPPP0HHHHHH00000000EEE0000000000000000000EE00000EE00000000
      0000PPPPP0GGGGHHHHHHHHH00
      EOS
    st.residues.select(&.has_backbone?).map(&.sec.code).join.should eq expected
  end
end
