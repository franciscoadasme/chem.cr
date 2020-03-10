require "../spec_helper"

describe Chem::Spatial do
  describe ".hlxparam" do
    it "returns helical parameters" do
      datasets = load_hlxparams_data
      st = load_file "4wfe.pdb"
      st.each_residue.compact_map(&.hlxparams).with_index do |params, i|
        params.zeta.should be_close datasets[:zeta][i], 1e-1
        params.theta.should be_close datasets[:theta][i], 2e-1
        # params.radius.should be_close datasets[:radius][i], 5e-1
      end
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
        structure = load_file "hlx_gly.poscar"
        structure.each_residue.map(&.hlxparams).each do |params|
          params = params.should_not be_nil
          params.theta.should be_close 166.15, 1e-2
          params.zeta.should be_close 2.91, 1e-3
          params.radius.should be_close 1.931, 1e-3
        end
      end
    end
  end
end
