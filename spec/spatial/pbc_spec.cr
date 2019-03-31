require "../spec_helper"

describe Chem::Spatial::PBC do
  describe "#wrap" do
    it "wraps atoms into the primary unit cell" do
      st = Chem::VASP::Poscar.read "spec/data/poscar/AlaIle--unwrapped.poscar"
      st.wrap

      expected = Chem::VASP::Poscar.read "spec/data/poscar/AlaIle--wrapped.poscar"
      st.each_atom.zip(expected.each_atom).each do |a, b|
        a.coords.should be_close b.coords, 1e-15
      end
    end

    it "wraps atoms into the primary unit cell in a non-rectangular lattice" do
      st = Chem::VASP::Poscar.read "spec/data/poscar/5e61--unwrapped.poscar"
      st.wrap

      expected = Chem::VASP::Poscar.read "spec/data/poscar/5e61--wrapped.poscar"
      st.each_atom.zip(expected.each_atom).each do |a, b|
        a.coords.should be_close b.coords, 1e-3
      end
    end

    it "wraps atoms into the primary unit cell centered at the origin" do
      st = Chem::VASP::Poscar.read "spec/data/poscar/5e61--unwrapped.poscar"
      st.wrap around: V.origin

      expected = Chem::VASP::Poscar.read "spec/data/poscar/5e61--wrapped--origin.poscar"
      st.each_atom.zip(expected.each_atom).each do |a, b|
        a.coords.should be_close b.coords, 1e-3
      end
    end
  end
end
