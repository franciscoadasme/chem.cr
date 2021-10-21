require "../spec_helper"

describe Chem::Spatial do
  describe ".hlxparam" do
    it "returns helical parameters" do
      data = {radius: [] of Float64, twist: [] of Float64, pitch: [] of Float64}.tap do |data|
        File.each_line(spec_file("spatial/hlxparams.txt")) do |line|
          next if line.blank?
          values = line.split.map &.to_f
          data[:pitch] << values[0]
          data[:twist] << values[1]
          data[:radius] << values[2]
        end
      end
      st = load_file "4wfe.pdb"
      st.each_residue.compact_map(&.hlxparams).with_index do |params, i|
        params.pitch.should be_close data[:pitch][i], 1e-1
        params.twist.should be_close data[:twist][i], 2e-1
        # params.radius.should be_close data[:radius][i], 5e-1
      end
    end

    it "correctly detects handedness of low-rise residues" do
      structure = load_file "hlx_phe--theta-90.000--c-26.10.pdb"
      structure.residues.map { |r| r.hlxparams.try(&.twist) || 0 }.should be_close [
        80.2, 107.6, 80.5, 106.2, 81.6, 107.6, 78.7, 111.5, 80.6, 106.0, 86.4,
        104.8, 79.8, 108.6, 79.9, 108.2, 81.5, 106.3, 80.4, 107.4, 80.6, 107.6,
        80.9, 106.9,
      ], 1e-1
    end

    it "returns nil when residue is terminal" do
      st = load_file "hlxparam.pdb"
      st.residues.first.hlxparams.should be_nil
      st.residues.last.hlxparams.should be_nil
    end

    it "returns nil when residue is not bonded to its previous/next residue" do
      st = load_file "hlxparam.pdb"
      # there is a gap between residues 2 and 3
      st.residues[2].hlxparams.should be_nil
      st.residues[3].hlxparams.should be_nil
    end

    context "given a periodic peptide" do
      it "returns helical parameters" do
        structure = load_file "hlx_gly.poscar", guess_topology: true
        structure.each_residue.map(&.hlxparams).each do |params|
          params = params.should_not be_nil
          params.twist.should be_close 166.15, 1e-2
          params.pitch.should be_close 2.91, 1e-3
          params.radius.should be_close 1.931, 1e-3
        end
      end
    end
  end
end
