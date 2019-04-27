require "../spec_helper.cr"

alias Poscar = Chem::VASP::Poscar

describe Chem::VASP::Poscar do
  describe ".parse" do
    it "parses a basic file" do
      st = Chem::Structure.read "spec/data/poscar/basic.poscar"
      st.size.should eq 49

      st.atoms.count(&.element.symbol.==("C")).should eq 14
      st.atoms.count(&.element.symbol.==("H")).should eq 21
      st.atoms.count(&.element.symbol.==("N")).should eq 7
      st.atoms.count(&.element.symbol.==("O")).should eq 7

      atom = st.atoms[-1]
      atom.chain.id.should eq 'A'
      atom.coords.should eq Vector[1.25020645, 3.42088266, 4.92610368]
      atom.element.oxygen?.should be_true
      atom.serial.should eq 49
      atom.name.should eq "O7"
      atom.occupancy.should eq 1
      atom.residue.name.should eq "UNK"
      atom.residue.number.should eq 1
      atom.serial.should eq 49
      atom.temperature_factor.should eq 0

      st.atoms[0].element.carbon?.should be_true
      st.atoms[14].element.hydrogen?.should be_true
      st.atoms[35].element.nitrogen?.should be_true
    end

    it "parses a file with direct coordinates" do
      st = Chem::Structure.read "spec/data/poscar/direct.poscar"
      st.atoms[0].coords.should eq Vector.origin
      st.atoms[1].coords.should be_close Vector[0.3, 0.45, 0.35], 1e-16
    end

    it "parses a file with selective dynamics" do
      st = Chem::Structure.read "spec/data/poscar/selective_dynamics.poscar"
      st.atoms[0].constraint.should eq Constraint::Z
      st.atoms[1].constraint.should eq Constraint::XYZ
      st.atoms[2].constraint.should eq Constraint::Z
    end

    it "fails when element symbols are missing" do
      msg = "Expected element symbols (vasp 5+) at 6:4"
      expect_raises(Chem::IO::ParseException, msg) do
        Chem::Structure.read "spec/data/poscar/no_symbols.poscar"
      end
    end

    it "fails when there are missing atomic species counts" do
      msg = "Mismatch between element symbols and counts at 7:5"
      expect_raises(Chem::IO::ParseException, msg) do
        Chem::Structure.read "spec/data/poscar/mismatch.poscar"
      end
    end
  end

  describe ".write" do
    structure = Chem::Structure.build do
      title "NaCl-O-NaCl"
      lattice 40, 20, 10
      atom PeriodicTable::Cl, at: V[30, 15, 10]
      atom PeriodicTable::Na, at: V[10, 5, 5]
      atom PeriodicTable::O, at: V[30, 15, 9]
      atom PeriodicTable::Na, at: V[10, 10, 12.5]
      atom PeriodicTable::Cl, at: V[20, 10, 10]
    end

    it "writes a structure in cartesian coordinates" do
      io = IO::Memory.new
      structure.write io, :poscar

      io.to_s.rstrip.should eq <<-EOS
        NaCl-O-NaCl
           1.00000000000000
            40.0000000000000000    0.0000000000000000    0.0000000000000000
             0.0000000000000000   20.0000000000000000    0.0000000000000000
             0.0000000000000000    0.0000000000000000   10.0000000000000000
           Cl   Na   O 
             2     2     1
        Cartesian
           30.0000000000000000   15.0000000000000000   10.0000000000000000
           20.0000000000000000   10.0000000000000000   10.0000000000000000
           10.0000000000000000    5.0000000000000000    5.0000000000000000
           10.0000000000000000   10.0000000000000000   12.5000000000000000
           30.0000000000000000   15.0000000000000000    9.0000000000000000
        EOS
    end

    it "writes a structure in fractional coordinates" do
      io = IO::Memory.new
      structure.write io, :poscar, fractional: true

      io.to_s.rstrip.should eq <<-EOS
        NaCl-O-NaCl
           1.00000000000000
            40.0000000000000000    0.0000000000000000    0.0000000000000000
             0.0000000000000000   20.0000000000000000    0.0000000000000000
             0.0000000000000000    0.0000000000000000   10.0000000000000000
           Cl   Na   O 
             2     2     1
        Direct
          0.7500000000000000  0.7500000000000000  1.0000000000000000
          0.5000000000000000  0.5000000000000000  1.0000000000000000
          0.2500000000000000  0.2500000000000000  0.5000000000000000
          0.2500000000000000  0.5000000000000000  1.2500000000000000
          0.7500000000000000  0.7500000000000000  0.9000000000000000
        EOS
    end

    it "writes a structure in fractional coordinates (wrapped)" do
      io = IO::Memory.new
      structure.write io, :poscar, fractional: true, wrap: true

      io.to_s.rstrip.should eq <<-EOS
        NaCl-O-NaCl
           1.00000000000000
            40.0000000000000000    0.0000000000000000    0.0000000000000000
             0.0000000000000000   20.0000000000000000    0.0000000000000000
             0.0000000000000000    0.0000000000000000   10.0000000000000000
           Cl   Na   O 
             2     2     1
        Direct
          0.7500000000000000  0.7500000000000000  1.0000000000000000
          0.5000000000000000  0.5000000000000000  1.0000000000000000
          0.2500000000000000  0.2500000000000000  0.5000000000000000
          0.2500000000000000  0.5000000000000000  0.2500000000000000
          0.7500000000000000  0.7500000000000000  0.9000000000000000
        EOS
    end

    it "writes a structure having constraints" do
      structure.atoms[0].constraint = Constraint::XYZ
      structure.atoms[3].constraint = Constraint::XZ

      io = IO::Memory.new
      structure.write io, :poscar

      io.to_s.rstrip.should eq <<-EOS
        NaCl-O-NaCl
           1.00000000000000
            40.0000000000000000    0.0000000000000000    0.0000000000000000
             0.0000000000000000   20.0000000000000000    0.0000000000000000
             0.0000000000000000    0.0000000000000000   10.0000000000000000
           Cl   Na   O 
             2     2     1
        Selective dynamics
        Cartesian
           30.0000000000000000   15.0000000000000000   10.0000000000000000   F   F   F
           20.0000000000000000   10.0000000000000000   10.0000000000000000   T   T   T
           10.0000000000000000    5.0000000000000000    5.0000000000000000   T   T   T
           10.0000000000000000   10.0000000000000000   12.5000000000000000   F   T   F
           30.0000000000000000   15.0000000000000000    9.0000000000000000   T   T   T
        EOS
    end

    it "fails with non-periodic structures" do
      expect_raises IO::Error, "Cannot write a non-periodic structure" do
        Poscar::Writer.new(IO::Memory.new) << Chem::Structure.new
      end
    end

    it "fails when writing multiple structures" do
      expect_raises IO::Error, "Cannot overwrite existing content" do
        writer = Poscar::Writer.new IO::Memory.new
        writer << structure << structure
      end
    end
  end
end
