require "../../spec_helper"

describe Chem::Topology::Templates::Detector do
  it "detects protein residues" do
    expected = {
      "ALA" => [
        [12, 13, 14, 78, 79, 80, 81, 82, 169, 183],
        [44, 45, 46, 128, 129, 130, 131, 132, 176, 193],
      ],
      "GLY" => [
        [10, 11, 75, 76, 77, 168, 182],
        [42, 43, 125, 126, 127, 175, 192],
      ],
      "SER" => [
        [27, 28, 29, 105, 106, 107, 108, 109, 172, 186, 187],
        [30, 31, 32, 110, 111, 112, 113, 114, 166, 173, 188, 189, 190],
        [59, 60, 61, 155, 156, 157, 158, 159, 179, 196, 197],
        [62, 63, 64, 160, 161, 162, 163, 164, 165, 180, 198, 199, 200],
      ],
    }

    path = "spec/data/poscar/5e61--unwrapped.poscar"
    residue_matches_helper(path, ["ALA", "GLY", "SER"]).should eq expected
  end

  it "detects terminal protein residues" do
    expected = {
      "ALA" => [
        [1, 2, 3, 10, 11, 13, 14, 15, 16, 29, 31],
      ],
      "ILE" => [
        [4, 5, 6, 7, 8, 9, 12, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 30, 32],
      ],
    }

    path = "spec/data/poscar/AlaIle--unwrapped.poscar"
    residue_matches_helper(path, ["ALA", "ILE"]).should eq expected
  end
end

def residue_matches_helper(path, codes)
  structure = Chem::Structure.read path
  builder = Chem::Topology::Builder.new structure
  builder.guess_bonds_from_geometry

  templates = codes.map { |code| Chem::Topology::Templates[code] }
  detector = Chem::Topology::Templates::Detector.new templates

  res_idxs = {} of String => Array(Array(Int32))
  detector.each_match(structure) do |res_t, idxs|
    res_idxs[res_t.code] ||= [] of Array(Int32)
    res_idxs[res_t.code] << idxs.keys.map(&.serial).sort!
  end
  res_idxs
end
