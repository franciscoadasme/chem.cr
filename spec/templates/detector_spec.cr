require "../spec_helper"

macro it_detects(description, path, expected)
  it "detects {{description.id}}" do
    %expected = {{expected}}

    %structure = load_file {{path}}, guess_bonds: true
    %templates = Chem::Templates::Registry.default.select &.name.in?(%expected.keys)
    %detector = Chem::Templates::Detector.new %structure.atoms

    %res_idxs = {} of String => Array(Hash(Int32, String))
    %matches, _ = %detector.detect(%templates)
    %matches.each do |m|
      %res_idxs[m.template.name] ||= [] of Hash(Int32, String)
      %res_idxs[m.template.name] << m.atom_map.invert.transform_keys(&.serial)
        .transform_values(&.name)
    end
    %res_idxs.should eq %expected
  end
end

describe Chem::Templates::Detector do
  it_detects "protein residues", "5e61--unwrapped.poscar", {
    "ALA" => [
      {12 => "CA", 13 => "CB", 14 => "C", 78 => "H", 79 => "HA", 80 => "HB2",
       81 => "HB3", 82 => "HB1", 169 => "N", 183 => "O"},
      {44 => "CA", 45 => "CB", 46 => "C", 128 => "H", 129 => "HA", 130 => "HB1",
       131 => "HB3", 132 => "HB2", 176 => "N", 193 => "O"},
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
       114 => "HG", 112 => "HB2", 113 => "HB1", 32 => "C", 189 => "O", 190 => "OXT",
       166 => "HXT"},
      {59 => "CA", 179 => "N", 155 => "H", 61 => "C", 197 => "O", 156 => "HA",
       60 => "CB", 196 => "OG", 159 => "HG", 157 => "HB2", 158 => "HB1"},
      {62 => "CA", 180 => "N", 160 => "H", 161 => "HA", 63 => "CB", 198 => "OG",
       164 => "HG", 162 => "HB2", 163 => "HB1", 64 => "C", 199 => "O", 200 => "OXT",
       165 => "HXT"},
    ],
  }

  it_detects "protein residues in a dipeptide", "AlaIle--unwrapped.poscar", {
    "ALA" => [
      {2 => "CA", 3 => "C", 29 => "O", 13 => "HA", 1 => "CB", 15 => "HB3",
       14 => "HB2", 16 => "HB1", 31 => "N", 10 => "H1", 11 => "H2"},
    ],
    "ILE" => [
      {4 => "CA", 32 => "N", 12 => "H", 17 => "HA", 6 => "CB", 7 => "CG1", 8 => "CD1",
       23 => "HD12", 24 => "HD11", 27 => "HD13", 21 => "HG12", 22 => "HG11", 9 => "CG2",
       19 => "HG23", 26 => "HG22", 20 => "HG21", 18 => "HB", 5 => "C", 28 => "O",
       30 => "OXT", 25 => "HXT"},
    ],
  }

  it_detects "charged terminal protein residues", "5e5v--unwrapped.poscar", {
    "ASN" => [
      {1 => "CA", 2 => "C", 201 => "O", 70 => "HA", 3 => "CB", 4 => "CG",
       186 => "ND2", 73 => "HD21", 74 => "HD22", 202 => "OD1", 72 => "HB1",
       71 => "HB2", 185 => "N", 67 => "H1", 68 => "H2", 69 => "H3"},
    ],
    "SER" => [
      {31 => "CA", 192 => "N", 114 => "H", 115 => "HA", 33 => "CB", 209 => "OG",
       118 => "HG", 117 => "HB2", 116 => "HB1", 32 => "C", 208 => "OXT", 210 => "O"},
      {64 => "CA", 200 => "N", 166 => "H", 167 => "HA", 66 => "CB", 219 => "OG",
       170 => "HG", 168 => "HB2", 169 => "HB1", 65 => "C", 218 => "O", 220 => "OXT"},
    ],
  }

  it_detects "waters", "5e5v--unwrapped.poscar", {
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

  it "detects a phospholipid" do
    templates = Chem::Templates::Registry.new
    templates.load spec_file("dmpe.mol2")
    structure = load_file "dmpe.xyz", guess_bonds: true
    detector = Chem::Templates::Detector.new structure.atoms
    matches, unmatched_atoms = detector.detect(templates)
    matches.size.should eq 1
    matches[0].atom_map.size.should eq 109
    unmatched_atoms.should be_empty
  end

  describe "#detect" do
    it "returns found matches" do
      structure = load_file "waters.xyz", guess_bonds: true
      matches, _ = Chem::Templates::Detector.new(structure.atoms).detect
      matches.group_by(&.template.name)
        .transform_values(&.map { |match|
          match.atom_map.transform_keys(&.name).transform_values(&.serial)
        })
        .should eq({
          "HOH" => [
            {"O" => 1, "H1" => 2, "H2" => 3},
            {"O" => 4, "H1" => 5, "H2" => 6},
            {"O" => 7, "H1" => 8, "H2" => 9},
          ],
        })
    end

    it "returns atoms not matched by any template" do
      structure = load_file "5e5v--unwrapped.poscar", guess_bonds: true
      registry = Chem::Templates::Registry.default.select &.name.==("HOH")
      detector = Chem::Templates::Detector.new structure.atoms
      _, unmatched_atoms = detector.detect registry
      unmatched_atoms.size.should eq 206
    end

    it "returns an empty array when all atoms are matched" do
      structure = load_file "waters.xyz", guess_bonds: true
      _, unmatched_atoms = Chem::Templates::Detector.new(structure.atoms).detect
      unmatched_atoms.should be_empty
    end
  end
end
