require "../spec_helper"

describe Chem::Protein::HlxParams do
  describe ".new" do
    it "returns helical parameters" do
      data = {radius: [] of Float64, twist: [] of Float64, pitch: [] of Float64}.tap do |data|
        File.each_line(spec_file("hlxparams_4wfe.txt")) do |line|
          next if line.blank?
          values = line.split.map &.to_f
          data[:pitch] << values[0]
          data[:twist] << values[1]
          data[:radius] << values[2]
        end
      end
      i = 0
      structure = load_file "4wfe.pdb"
      structure.residues.each do |residue|
        params = Chem::Protein::HlxParams.new(residue) rescue next
        params.pitch.should be_close data[:pitch][i], 1e-1
        params.twist.degrees.should be_close data[:twist][i], 2e-1
        i += 1
      end
    end

    it "correctly detects handedness of low-rise residues" do
      expected = [
        80.2, 107.6, 80.5, 106.2, 81.6, 107.6, 78.7, 111.5, 80.6, 106.0, 86.4,
        104.8, 79.8, 108.6, 79.9, 108.2, 81.5, 106.3, 80.4, 107.4, 80.6, 107.6,
        80.9, 106.9,
      ]
      structure = load_file "hlx_phe--theta-90.000--c-26.10.pdb"
      twist = structure.residues.map do |residue|
        Chem::Protein::HlxParams.new(residue).twist.degrees
      end
      twist.should be_close expected, 1e-1
    end

    it "raises if residue is N-ter" do
      structure = load_file "hlxparam.pdb"
      expect_raises(ArgumentError) do
        Chem::Protein::HlxParams.new structure.residues.first
      end
    end

    it "raises if residue is C-ter" do
      structure = load_file "hlxparam.pdb"
      expect_raises(ArgumentError) do
        Chem::Protein::HlxParams.new structure.residues.last
      end
    end

    it "raises if residue is not bonded to its previous/next residue" do
      # there is a gap between residues 2 and 3
      structure = load_file "hlxparam.pdb"
      expect_raises(ArgumentError) do
        Chem::Protein::HlxParams.new structure.residues[2]
      end
      expect_raises(ArgumentError) do
        Chem::Protein::HlxParams.new structure.residues[3]
      end
    end

    context "given a periodic peptide" do
      it "returns helical parameters" do
        structure = load_file "hlx_gly.poscar", guess_bonds: true, guess_names: true
        structure.residues.each do |residue|
          params = Chem::Protein::HlxParams.new residue
          params.twist.degrees.should be_close 166.15, 1e-2
          params.pitch.should be_close 2.91, 1e-3
          params.radius.should be_close 1.931, 1e-3
        end
      end

      it "computes pitch for a 2-residue peptide (#97)" do
        structure = load_file "polyala--theta-180.000--c-10.00.pdb"
        structure.residues.each do |residue|
          params = Chem::Protein::HlxParams.new residue
          params.pitch.should be_close 2.65, 1e-2
          params.twist.degrees.should be_close 180, 1e-2
        end
      end
    end
  end
end
