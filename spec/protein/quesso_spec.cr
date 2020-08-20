require "../spec_helper"

describe Chem::Protein::QUESSO do
  it "assigns secondary structure (1cbn)" do
    st = load_file "1cbn.pdb"
    Chem::Protein::QUESSO.assign st
    actual = st.residues.select(&.has_backbone?).map(&.sec.code).join
    actual.should eq "0EEESSHHHHHHHHGGGGGSSSHHHHHHHHSSEEESSSSUSGGGG0"
  end

  it "assigns secondary structure (1dpo)" do
    st = load_file "1dpo.pdb"
    Chem::Protein::QUESSO.assign st
    expected = <<-EOS.gsub(/\s+/, "")
      0SSSSPPPPSSSUSSEEESSSSSSSSEESSSSSEEEESGGGSSSEEEEESSSSSSSSSSSSSEEEE
      ESSUPPPSSSSSUSSSSSEEEEEESSUUUUSSSSPPPPPPSSPPPPSEEEEEEESSSSSSSSEEES
      SPPPPPPPPPPPSHHHHHHSSSSSSSSEEESSSSSSSSSSSSSSSSSUSEESSSSSEESSSSSSSS
      SSSSPPPPPSGGGGHHHHHHHHHH0
      EOS
    st.residues.select(&.has_backbone?).map(&.sec.code).join.should eq expected
  end
end
