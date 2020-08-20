require "../spec_helper"

describe Chem::Protein::DSSP do
  it "assigns secondary structure (1cbn)" do
    st = load_file "1cbn.pdb"
    Chem::Protein::DSSP.assign st
    actual = st.each_residue.select(&.has_backbone?).map(&.dssp).join
    actual.should eq "0EE0SSHHHHHHHHHHHTTT00HHHHHHHHS0EE0SSS000TTS00"
  end

  it "assigns secondary structure (1dpo)" do
    st = load_file "1dpo.pdb"
    Chem::Protein::DSSP.assign st
    expected = "0BS0EE00TT0STTEEEEESSSEEEEEEEEETTEEEE0GGG00SS0EEEES0SBTTS00S00EEEEEEEEE\
                E0TT00TTT0TT00EEEEESS0000BTTB000B00SS000TT0EEEEEESS000SSS0000SB0EEEEEEB\
                00HHHHHHHSTTT00TTEEEES0TT0S0B00TT0TT0EEEETTEEEEEEEE0SSSS0TT00EEEEEGGG0H\
                HHHHHHHHH0"
    actual = st.each_residue.select(&.has_backbone?).map(&.dssp).join
    actual.should eq expected
  end

  it "assigns secondary structure (1etl)" do
    st = load_file "1etl.pdb"
    Chem::Protein::DSSP.assign st
    actual = st.each_residue.select(&.has_backbone?).map(&.dssp).join
    actual.should eq "0TT00STTSTT0"
  end

  it "assigns secondary structure (3e2o)" do
    st = load_file "3e2o.pdb"
    Chem::Protein::DSSP.assign st
    expected = "00EE0000TT00HHHHHHHHHHHHHHHHH0TTHHHHT0SHHHHHHHHHHHHTT0BTTTTBSSSTT0GGGSH\
                HHHT0GGGTTTHHHHHHHHHHHHH0TTS0HHHHHHHHHHHHHHHTT00000B00000000GGG000S00S0\
                0SS00HHHHHHHHHTTT00HHHHHHHHGGGGSSEE0HHHHS00EESSS0TTS0SSHHHHHHHHS0EEEEE0\
                TTS0EEEEETTS0EE0HHHHHHHHSHHHHHHHHHHHT0HHHHHHHHHHHHHHHHHTTEE00TTS000B000\
                0HHHHT0"
    actual = st.each_residue.select(&.has_backbone?).map(&.dssp).join
    actual.should eq expected
  end

  it "assigns secondary structure (4ayo)" do
    st = load_file "4ayo.pdb"
    Chem::Protein::DSSP.assign st
    expected = "0000HHHHHHHHHHHHHHHHHHHHHHHTTSSEEETTTTEEE0SSSTT0000HHHHHHHHHHHHTT0HHHHH\
                HHHHHHHHH00000SSEEEHHHIIIIIIHHHHHHHHHH00HHHHHHHHHHHHHHHHHHHTSTT0000SEEE\
                TTT00EE00EEEHHHHSS0HHHHHHHHHHH00THHHHHHHHHHHHHHTT00TTS000SEEETTT00BS00E\
                E0SSTTTHHHHHHHHHHHHHH00HHHHHHHHHHHHHHHHHT0EEETTEEE000EETTT00B000EEEGGGG\
                HHHHHHHHTT0HHHHHHHHHHHHHHHHHHSS00SEEETTTTEES0S000000HHHHHHHHHHHHH00HHHH\
                HHHHHHHHHHHHHSEETTEE00EEESSSSS0EE0S000HHHHHTHHHHHHHHHH00TTB0TTT0EE0TT00\
                EEE0B000"
    actual = st.each_residue.select(&.has_backbone?).map(&.dssp).join
    actual.should eq expected
  end

  it "assigns secondary structure (4wfe:G), gaps" do
    st = Structure.from_pdb "spec/data/pdb/4wfe.pdb", chains: ['G']
    Chem::Protein::DSSP.assign st
    expected = "00EEEE000EEE0TT00EEEEEEEESS0GGGS0EEEEEE0TTS0EEEEEEE0TTT00EEE0GGGTTTEEEE\
                EETTTTEEEEEE0S00GGG0EEEEEEE0SSS00EE000EEEEE00000B00EEEEE0000EEEEEEEEEEE\
                BSS00EEEEgggT00TTEEE000EEETTEEEEEEEEEEETTTTTTS00EEEEEEGGGTEEEEEE0000"
    actual = st['G'].each_residue.select(&.has_backbone?).map(&.dssp).join
    actual.should eq expected
  end

  it "assigns secondary structure (5jqf)" do
    st = load_file "5jqf.pdb"
    Chem::Protein::DSSP.assign st
    actual = st.each_residue.select(&.has_backbone?).map(&.dssp).join
    actual.should eq "00EEEEEE0TTTSSE0SEEE000EEEEEE0TTTSSE0SEEE0"
  end
end
