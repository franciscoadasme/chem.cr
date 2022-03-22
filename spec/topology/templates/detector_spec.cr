require "../../spec_helper"

describe Chem::Topology::Templates::Detector do
  it "detects protein residues" do
    expected = {
      "ALA" => [
        {12 => "CA", 13 => "CB", 14 => "C", 78 => "H", 79 => "HA", 80 => "HB2",
         81 => "HB1", 82 => "HB3", 169 => "N", 183 => "O"},
        {44 => "CA", 45 => "CB", 46 => "C", 128 => "H", 129 => "HA", 130 => "HB1",
         131 => "HB2", 132 => "HB3", 176 => "N", 193 => "O"},
      ],
      "GLY" => [
        {10 => "CA", 11 => "C", 75 => "H", 76 => "HA2", 77 => "HA1", 168 => "N",
         182 => "O"},
        {42 => "CA", 43 => "C", 125 => "H", 126 => "HA1", 127 => "HA2", 175 => "N",
         192 => "O"},
      ],
      "SER" => [
        {27 => "CA", 28 => "CB", 29 => "C", 105 => "H", 106 => "HA", 107 => "HB2",
         108 => "HB1", 109 => "HG", 172 => "N", 186 => "OG", 187 => "O"},
        {30 => "CA", 173 => "N", 110 => "H", 111 => "HA", 31 => "CB", 188 => "OG",
         114 => "HG", 112 => "HB1", 113 => "HB2", 32 => "C", 189 => "O", 190 => "OXT",
         166 => "HXT"},
        {59 => "CA", 179 => "N", 155 => "H", 61 => "C", 197 => "O", 156 => "HA",
         60 => "CB", 196 => "OG", 159 => "HG", 157 => "HB1", 158 => "HB2"},
        {62 => "CA", 180 => "N", 160 => "H", 161 => "HA", 63 => "CB", 198 => "OG",
         164 => "HG", 162 => "HB2", 163 => "HB1", 64 => "C", 199 => "O", 200 => "OXT",
         165 => "HXT"},
      ],
    }
    residue_matches_helper("5e61--unwrapped.poscar", ["ALA", "GLY", "SER"]).should eq expected
  end

  it "detects protein residues in a dipeptide" do
    expected = {
      "ALA" => [
        {2 => "CA", 3 => "C", 29 => "O", 13 => "HA", 1 => "CB", 15 => "HB1",
         14 => "HB2", 16 => "HB3", 31 => "N", 10 => "H1", 11 => "H2"},
      ],
      "ILE" => [
        {4 => "CA", 32 => "N", 12 => "H", 17 => "HA", 6 => "CB", 7 => "CG1", 8 => "CD1",
         23 => "HD12", 24 => "HD13", 27 => "HD11", 21 => "HG12", 22 => "HG11", 9 => "CG2",
         19 => "HG21", 26 => "HG22", 20 => "HG23", 18 => "HB", 5 => "C", 28 => "O",
         30 => "OXT", 25 => "HXT"},
      ],
    }
    residue_matches_helper("AlaIle--unwrapped.poscar", ["ALA", "ILE"]).should eq expected
  end

  it "detects charged terminal protein residues" do
    expected = {
      "ASN" => [
        {1 => "CA", 2 => "C", 201 => "O", 70 => "HA", 3 => "CB", 4 => "CG",
         186 => "ND2", 73 => "HD21", 74 => "HD22", 202 => "OD1", 72 => "HB1",
         71 => "HB2", 185 => "N", 67 => "H1", 68 => "H2", 69 => "H3"},
      ],
      "SER" => [
        {31 => "CA", 192 => "N", 114 => "H", 115 => "HA", 33 => "CB", 209 => "OG",
         118 => "HG", 117 => "HB2", 116 => "HB1", 32 => "C", 208 => "O", 210 => "OXT"},
        {64 => "CA", 200 => "N", 166 => "H", 167 => "HA", 66 => "CB", 219 => "OG",
         170 => "HG", 168 => "HB2", 169 => "HB1", 65 => "C", 218 => "OXT", 220 => "O"},
      ],
    }
    residue_matches_helper("5e5v--unwrapped.poscar", ["ASN", "SER"]).should eq expected
  end

  it "detects waters" do
    expected = {
      "HOH" => [
        {221 => "O", 171 => "H1", 172 => "H2"},
        {222 => "O", 173 => "H1", 174 => "H2"},
        {223 => "O", 175 => "H1", 176 => "H2"},
        {224 => "O", 177 => "H1", 178 => "H2"},
        {225 => "O", 179 => "H1", 180 => "H2"},
        {226 => "O", 181 => "H1", 182 => "H2"},
        {227 => "O", 183 => "H1", 184 => "H2"},
      ],
    }
    residue_matches_helper("5e5v--unwrapped.poscar", ["HOH"]).should eq expected
  end

  describe "#matches" do
    it "returns found matches" do
      structure = load_file "waters.xyz"
      matches = Chem::Topology::Templates::Detector.new(structure).matches
      matches.should eq [
        Chem::Topology::MatchData.new(Chem::ResidueType.fetch("HOH"), {
          "O"  => structure.atoms[0],
          "H1" => structure.atoms[1],
          "H2" => structure.atoms[2],
        }),
        Chem::Topology::MatchData.new(Chem::ResidueType.fetch("HOH"), {
          "O"  => structure.atoms[3],
          "H1" => structure.atoms[4],
          "H2" => structure.atoms[5],
        }),
        Chem::Topology::MatchData.new(Chem::ResidueType.fetch("HOH"), {
          "O"  => structure.atoms[6],
          "H1" => structure.atoms[7],
          "H2" => structure.atoms[8],
        }),
      ]
    end
  end

  describe "#unmatched_atoms" do
    it "returns atoms not matched by any template" do
      structure = load_file "5e5v--unwrapped.poscar"
      detector = Chem::Topology::Templates::Detector.new structure, [Chem::ResidueType.fetch("HOH")]
      detector.each_match { } # triggers search
      detector.unmatched_atoms.try(&.size).should eq 206
    end

    it "returns an empty array when all atoms are matched" do
      structure = load_file "waters.xyz"
      detector = Chem::Topology::Templates::Detector.new structure
      detector.each_match { } # triggers search
      detector.unmatched_atoms.empty?.should be_true
    end
  end
end

def residue_matches_helper(path, names)
  templates = names.map { |name| Chem::ResidueType.fetch(name) }

  structure = load_file path
  detector = Chem::Topology::Templates::Detector.new structure, templates

  res_idxs = {} of String => Array(Hash(Int32, String))
  detector.each_match do |m|
    res_idxs[m.resname] ||= [] of Hash(Int32, String)
    res_idxs[m.resname] << m.to_h.invert.transform_keys(&.serial)
  end
  res_idxs
end
