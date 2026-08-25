require "compress/gzip"
require "../spec_helper"

describe Chem::Maestro do
  describe ".read" do
    it "parses a Maestro file" do
      path = Path[spec_file("plain.mae")]
      struc = Chem::Maestro.read path
      struc.source_file.should eq path.expand
      struc.title.should eq %(Title with p \\ " space)
      struc.metadata["s_m_entry_name"].as_s.should eq "ligprep-out.1"
      struc.metadata["s_sd_Formula"].as_s.should eq "CH2O2"
      struc.metadata["b_mmod_Minimization_Converged-OPLS-2005"].as_bool.should be_true

      struc.chains.size.should eq 1
      struc.residues.size.should eq 1
      struc.dig('A', 900).name.should eq "UNK"

      atoms = struc.atoms
      atoms.size.should eq 5
      atoms.map(&.element.symbol).should eq %w(C O O H H)
      atoms[0].name.should eq %(Does p " \\this work)
      atoms[1].name.should eq "O1"
      atoms[0].pos.should be_close [1.322943, 0.665651, 0.033620], 1e-6
      atoms[0].partial_charge.should eq 0.52
      atoms[2].partial_charge.should eq -0.53
      atoms[4].formal_charge.should eq 0

      struc.bonds.size.should eq 4
      atoms[0].bonds[atoms[1]].order.should eq 2
      atoms[0].bonds[atoms[2]].order.should eq 1
      atoms[0].bonds[atoms[3]].order.should eq 1
      atoms[2].bonds[atoms[4]].order.should eq 1
    end

    it "fails when a bond atom index is zero" do
      expect_raises(Chem::ParseException, "Atom index 0 out of range") do
        Chem::Maestro.read mae_with_bond(0, 1)
      end
    end

    it "fails when a bond atom index is past the atom count" do
      expect_raises(Chem::ParseException, "Atom index 3 out of range") do
        Chem::Maestro.read mae_with_bond(1, 3)
      end
    end

    it "fails when i_m_from is missing" do
      expect_raises(Chem::ParseException, "Missing i_m_from") do
        Chem::Maestro.read mae_with_bond(1, 2, %w(i_m_to i_m_order))
      end
    end

    it "reads a bond listed only in reverse index order" do
      struc = Chem::Maestro.read mae_with_bond(2, 1)
      struc.bonds.size.should eq 1
      struc.atoms[0].bonded?(struc.atoms[1]).should be_true
    end

    it "fails when the bond order is invalid" do
      expect_raises(Chem::ParseException, "Invalid bond order 5") do
        Chem::Maestro.read mae_with_bond(1, 2, order: 5)
      end
    end

    it "fails when a property key is invalid" do
      io = IO::Memory.new <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          foo
          :::
          x
        }
        EOS
      ex = expect_raises(Chem::ParseException, /Invalid property .*foo/) do
        Chem::Maestro.read io
      end
      ex.line.not_nil!.should contain "foo"
    end

    it "does not store title or CRYST1 fields in metadata" do
      struc = Chem::Maestro.read mae_with_cell(10, 20, 30, 90, 90, 90)
      struc.title.should eq "x"
      struc.metadata.has_key?("s_m_title").should be_false
      %w(r_pdb_PDB_CRYST1_a
        r_pdb_PDB_CRYST1_b
        r_pdb_PDB_CRYST1_c
        r_pdb_PDB_CRYST1_alpha
        r_pdb_PDB_CRYST1_beta
        r_pdb_PDB_CRYST1_gamma).each do |key|
        struc.metadata.has_key?(key).should be_false
      end
    end

    it "omits undefined <> columns from metadata" do
      io = IO::Memory.new <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          i_user_n
          b_user_flag
          :::
          x
          <>
          0
          m_atom[1] {
            i_m_atomic_number
            r_m_charge2
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            :::
            1 6 <> 0 0 0
            :::
          }
        }
        EOS
      struc = Chem::Maestro.read io
      struc.metadata.has_key?("i_user_n").should be_false
      struc.metadata["b_user_flag"].as_bool.should be_false
      struc.atoms[0].metadata.has_key?("r_m_charge2").should be_false
    end

    it "treats <> as unset for residue number, serial, and occupancy" do
      io = IO::Memory.new <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          x
          m_atom[1] {
            i_m_atomic_number
            i_m_residue_number
            i_pdb_PDB_serial
            r_m_pdb_occupancy
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            :::
            1 6 <> <> <> 0 0 0
            :::
          }
        }
        EOS
      atom = Chem::Maestro.read(io).atoms[0]
      atom.residue?.should be_nil
      atom.number.should eq 1
      atom.occupancy.should eq 1
    end

    it "uses r_m_charge1 for partial charge" do
      io = IO::Memory.new <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          x
          m_atom[1] {
            i_m_atomic_number
            r_m_charge1
            r_m_charge2
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            :::
            1 6 0.5 9.9 0 0 0
            :::
          }
        }
        EOS
      atom = Chem::Maestro.read(io).atoms[0]
      atom.partial_charge.should eq 0.5
      atom.metadata["r_m_charge2"].as_f.should eq 9.9
    end

    it "fails when i_m_atomic_number is missing" do
      io = IO::Memory.new <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          x
          m_atom[1] {
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            :::
            1 0 0 0
            :::
          }
        }
        EOS
      expect_raises(Chem::ParseException, "Missing i_m_atomic_number") do
        Chem::Maestro.read io
      end
    end

    it "fails when the atomic number is invalid" do
      io = IO::Memory.new <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          x
          m_atom[1] {
            i_m_atomic_number
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            :::
            1 0 0 0 0
            :::
          }
        }
        EOS
      expect_raises(Chem::ParseException, %(Invalid atomic number "0")) do
        Chem::Maestro.read io
      end
    end

    it "reads a unit cell from CRYST1 fields" do
      struc = Chem::Maestro.read mae_with_cell(10, 20, 30, 90, 90, 90)
      struc.cell.size.should eq Chem::Spatial::Size3[10, 20, 30]
    end

    it "fails when the cell is invalid" do
      expect_raises(Chem::ParseException, "Invalid cell size a") do
        Chem::Maestro.read mae_with_cell(0, 20, 30, 90, 90, 90)
      end
    end

    it "skips comments that contain braces" do
      io = IO::Memory.new <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          x
          # ignored } { #
          #{mae_one_atom}
        }
        EOS
      Chem::Maestro.read(io).atoms.size.should eq 1
    end

    it "reads a nested block that ends on the same line as the next header" do
      io = IO::Memory.new <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          x
          m_foo {
            s_m_bar
            :::
            1
          } m_atom[1] {
            i_m_atomic_number
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            :::
            1 6 0 0 0
            :::
          }
        }
        EOS
      Chem::Maestro.read(io).atoms.size.should eq 1
    end

    it "does not treat a quoted brace as a block closer" do
      io = IO::Memory.new <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          "has } brace"
          #{mae_one_atom}
        }
        EOS
      Chem::Maestro.read(io).title.should eq "has } brace"
    end

    it "reads multiple property values on one line" do
      io = IO::Memory.new <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          i_user_n
          :::
          hello 7
          #{mae_one_atom}
        }
        EOS
      struc = Chem::Maestro.read io
      struc.title.should eq "hello"
      struc.metadata["i_user_n"].as_i.should eq 7
    end
  end

  describe ".read_all" do
    it "returns all structures" do
      ary = Chem::Maestro.read_all spec_file("plain.mae")
      ary.size.should eq 3
      ary.map(&.atoms.size).should eq [5, 9, 7]
      ary[1].title.should eq "2:Acids"
      ary[1].atoms.map(&.element.symbol).should eq %w(C N O O N O O H H)
      ary[1].atoms[1].formal_charge.should eq 1
      ary[1].atoms[3].formal_charge.should eq -1
      ary[2].title.should eq "3:Acids"
    end

    it "reads adjacent CT blocks without a blank line" do
      io = IO::Memory.new <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          a
          #{mae_one_atom}
        }f_m_ct {
          s_m_title
          :::
          b
          #{mae_one_atom}
        }
        EOS
      ary = Chem::Maestro.read_all io
      ary.map(&.title).should eq %w(a b)
    end
  end

  describe ".write" do
    it "writes topology, bonds, charges, and metadata" do
      struc = Chem::Structure.build do
        title "formic"
        chain 'A' do
          residue "UNK", 900 do
            atom "C1", vec3(1.322943, 0.665651, 0.033620), partial_charge: 0.52
            atom "O1", vec3(1.9, 0.1, 0.0), partial_charge: -0.53
            atom "O2", vec3(0.4, 1.1, 0.0), formal_charge: -1, partial_charge: -0.53
            atom "H1", vec3(2.1, 0.8, 0.0)
            atom "H2", vec3(0.1, 0.2, 0.0)
            bond "C1", "O1", :double
            bond "C1", "O2"
            bond "C1", "H1"
            bond "O2", "H2"
          end
        end
      end
      struc.metadata["s_m_entry_name"] = "ligprep-out.1"
      struc.metadata["b_user_flag"] = false
      struc.metadata["i_user_n"] = 7
      struc.metadata["note"] = "hello"
      struc.metadata["i_user_arr"] = [1, 2]
      struc.atoms[0].metadata["i_m_color"] = 2
      struc.atoms[0].metadata["label"] = "x"

      io = IO::Memory.new
      Chem::Maestro.write io, struc
      io.to_s.should eq <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          s_m_entry_name
          b_user_flag
          i_user_n
          s_user_note
          :::
          formic
          ligprep-out.1
          0
          7
          hello
          m_atom[5] {
            i_m_atomic_number
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            i_m_formal_charge
            r_m_charge1
            s_m_pdb_atom_name
            r_m_pdb_occupancy
            r_m_pdb_tfactor
            i_pdb_PDB_serial
            i_m_residue_number
            s_m_pdb_residue_name
            s_m_insertion_code
            s_m_chain_name
            i_m_color
            s_user_label
            :::
            1 6 1.322943 0.665651 0.03362 0 0.52 C1 1.0 0.0 1 900 UNK <> A 2 x
            2 8 1.9 0.1 0.0 0 -0.53 O1 1.0 0.0 2 900 UNK <> A <> <>
            3 8 0.4 1.1 0.0 -1 -0.53 O2 1.0 0.0 3 900 UNK <> A <> <>
            4 1 2.1 0.8 0.0 0 0.0 H1 1.0 0.0 4 900 UNK <> A <> <>
            5 1 0.1 0.2 0.0 0 0.0 H2 1.0 0.0 5 900 UNK <> A <> <>
            :::
          }
          m_bond[4] {
            i_m_from
            i_m_to
            i_m_order
            :::
            1 1 2 2
            2 1 3 1
            3 1 4 1
            4 3 5 1
            :::
          }
        }\n
        EOS
    end

    it "writes a unit cell" do
      struc = Chem::Structure.build do
        title "x"
        atom Chem::PeriodicTable::C, vec3(0, 0, 0)
      end
      struc.cell = Chem::Spatial::Parallelepiped.new({10, 20, 30}, {90, 90, 90})

      io = IO::Memory.new
      Chem::Maestro.write io, struc
      io.to_s.should eq <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          r_pdb_PDB_CRYST1_a
          r_pdb_PDB_CRYST1_b
          r_pdb_PDB_CRYST1_c
          r_pdb_PDB_CRYST1_alpha
          r_pdb_PDB_CRYST1_beta
          r_pdb_PDB_CRYST1_gamma
          :::
          x
          10.0
          20.0
          30.0
          90.0
          90.0
          90.0
          m_atom[1] {
            i_m_atomic_number
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            i_m_formal_charge
            r_m_charge1
            s_m_pdb_atom_name
            r_m_pdb_occupancy
            r_m_pdb_tfactor
            i_pdb_PDB_serial
            :::
            1 6 0.0 0.0 0.0 0 0.0 C1 1.0 0.0 1
            :::
          }
        }\n
        EOS
    end

    it "quotes strings that the reader would otherwise tokenize" do
      struc = Chem::Structure.build do
        title %(Title with p \\ " space)
        chain 'A' do
          residue "UNK", 1 do
            atom "C1", vec3(0, 0, 0)
          end
        end
      end
      struc.atoms[0].name = %(Does p " \\this work)

      io = IO::Memory.new
      Chem::Maestro.write io, struc
      title = %("Title with p \\\\ \\" space")
      name = %("Does p \\" \\\\this work")
      io.to_s.should eq <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          #{title}
          m_atom[1] {
            i_m_atomic_number
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            i_m_formal_charge
            r_m_charge1
            s_m_pdb_atom_name
            r_m_pdb_occupancy
            r_m_pdb_tfactor
            i_pdb_PDB_serial
            i_m_residue_number
            s_m_pdb_residue_name
            s_m_insertion_code
            s_m_chain_name
            :::
            1 6 0.0 0.0 0.0 0 0.0 #{name} 1.0 0.0 1 1 UNK <> A
            :::
          }
        }\n
        EOS
    end

    it "writes occupancy, serial, and insertion code" do
      struc = Chem::Structure.build do
        title "x"
        chain 'B' do
          residue "LIG", 12, 'A' do
            atom "C1", 42, vec3(0, 0, 0), occupancy: 0.5, temperature_factor: 1.2
          end
        end
      end

      io = IO::Memory.new
      Chem::Maestro.write io, struc
      io.to_s.should eq <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          x
          m_atom[1] {
            i_m_atomic_number
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            i_m_formal_charge
            r_m_charge1
            s_m_pdb_atom_name
            r_m_pdb_occupancy
            r_m_pdb_tfactor
            i_pdb_PDB_serial
            i_m_residue_number
            s_m_pdb_residue_name
            s_m_insertion_code
            s_m_chain_name
            :::
            1 6 0.0 0.0 0.0 0 0.0 C1 0.5 1.2 42 12 LIG A B
            :::
          }
        }\n
        EOS
    end

    it "writes named atoms without topology" do
      struc = Chem::Structure.new
      struc.title = "x"
      Chem::Atom.new struc, Chem::PeriodicTable::C, vec3(0, 0, 0), name: "C1"
      Chem::Atom.new struc, Chem::PeriodicTable::O, vec3(1, 0, 0), name: "O1"
      struc.atoms[0].bonds.add struc.atoms[1], :double

      io = IO::Memory.new
      Chem::Maestro.write io, struc
      io.to_s.should eq <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          x
          m_atom[2] {
            i_m_atomic_number
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            i_m_formal_charge
            r_m_charge1
            s_m_pdb_atom_name
            r_m_pdb_occupancy
            r_m_pdb_tfactor
            i_pdb_PDB_serial
            :::
            1 6 0.0 0.0 0.0 0 0.0 C1 1.0 0.0 1
            2 8 1.0 0.0 0.0 0 0.0 O1 1.0 0.0 2
            :::
          }
          m_bond[1] {
            i_m_from
            i_m_to
            i_m_order
            :::
            1 1 2 2
            :::
          }
        }\n
        EOS
    end

    it "writes nameless atoms as undefined names" do
      struc = Chem::Structure.new
      struc.title = "x"
      Chem::Atom.new struc, Chem::PeriodicTable::C, vec3(1, 2, 3)

      io = IO::Memory.new
      Chem::Maestro.write io, struc
      io.to_s.should eq <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          x
          m_atom[1] {
            i_m_atomic_number
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            i_m_formal_charge
            r_m_charge1
            s_m_pdb_atom_name
            r_m_pdb_occupancy
            r_m_pdb_tfactor
            i_pdb_PDB_serial
            :::
            1 6 1.0 2.0 3.0 0 0.0 <> 1.0 0.0 1
            :::
          }
        }\n
        EOS
    end

    it "writes multiple structures" do
      a = Chem::Structure.build do
        title "a"
        atom Chem::PeriodicTable::C, vec3(0, 0, 0)
      end
      b = Chem::Structure.build do
        title "b"
        atom Chem::PeriodicTable::C, vec3(1, 0, 0)
      end
      io = IO::Memory.new
      Chem::Maestro.write io, [a, b]
      io.to_s.should eq <<-EOS
        {
          s_m_m2io_version
          :::
          2.0.0
        }
        f_m_ct {
          s_m_title
          :::
          a
          m_atom[1] {
            i_m_atomic_number
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            i_m_formal_charge
            r_m_charge1
            s_m_pdb_atom_name
            r_m_pdb_occupancy
            r_m_pdb_tfactor
            i_pdb_PDB_serial
            :::
            1 6 0.0 0.0 0.0 0 0.0 C1 1.0 0.0 1
            :::
          }
        }

        f_m_ct {
          s_m_title
          :::
          b
          m_atom[1] {
            i_m_atomic_number
            r_m_x_coord
            r_m_y_coord
            r_m_z_coord
            i_m_formal_charge
            r_m_charge1
            s_m_pdb_atom_name
            r_m_pdb_occupancy
            r_m_pdb_tfactor
            i_pdb_PDB_serial
            :::
            1 6 1.0 0.0 0.0 0 0.0 C1 1.0 0.0 1
            :::
          }
        }\n
        EOS
    end

    it "compresses .maegz by path" do
      struc = Chem::Structure.new
      struc.title = "x"
      Chem::Atom.new struc, Chem::PeriodicTable::C, vec3(0, 0, 0)
      expected = String.build { |io| Chem::Maestro.write io, struc }
      path = File.tempname("out", ".maegz")
      begin
        Chem::Maestro.write path, struc
        Compress::Gzip::Reader.open(path, &.gets_to_end).should eq expected
      ensure
        File.delete?(path)
      end
    end

    it "compresses .mae.gz by path" do
      struc = Chem::Structure.new
      struc.title = "x"
      Chem::Atom.new struc, Chem::PeriodicTable::C, vec3(0, 0, 0)
      expected = String.build { |io| Chem::Maestro.write io, struc }
      path = File.tempname("out", ".mae.gz")
      begin
        Chem::Maestro.write path, struc
        Compress::Gzip::Reader.open(path, &.gets_to_end).should eq expected
      ensure
        File.delete?(path)
      end
    end
  end

  describe "compressed files" do
    it "decompresses .maegz by path" do
      with_gzip_mae(".maegz") do |path|
        ary = Chem::Maestro.read_all path
        ary.size.should eq 3
        ary[0].source_file.should eq Path[path].expand
      end
    end

    it "decompresses .mae.gz by path" do
      with_gzip_mae(".mae.gz") do |path|
        Chem::Maestro.read(path).atoms.size.should eq 5
      end
    end
  end
end

private def mae_with_bond(
  from : Int32,
  to : Int32,
  bond_columns : Array(String) = %w(i_m_from i_m_to i_m_order),
  order : Int32 = 1,
) : IO::Memory
  values = {
    "i_m_from"  => from,
    "i_m_to"    => to,
    "i_m_order" => order,
  }
  cols = bond_columns.join('\n')
  row = bond_columns.map { |name| values[name] }.join("  ")
  IO::Memory.new <<-EOS
    {
      s_m_m2io_version
      :::
      2.0.0
    }
    f_m_ct {
      s_m_title
      :::
      x
      m_atom[2] {
        i_m_atomic_number
        r_m_x_coord
        r_m_y_coord
        r_m_z_coord
        :::
        1 6 0 0 0
        2 8 1 0 0
        :::
      }
      m_bond[1] {
        #{cols}
        :::
        1  #{row}
        :::
      }
    }
    EOS
end

private def mae_with_cell(
  a : Number,
  b : Number,
  c : Number,
  alpha : Number,
  beta : Number,
  gamma : Number,
) : IO::Memory
  IO::Memory.new <<-EOS
    {
      s_m_m2io_version
      :::
      2.0.0
    }
    f_m_ct {
      s_m_title
      r_pdb_PDB_CRYST1_a
      r_pdb_PDB_CRYST1_b
      r_pdb_PDB_CRYST1_c
      r_pdb_PDB_CRYST1_alpha
      r_pdb_PDB_CRYST1_beta
      r_pdb_PDB_CRYST1_gamma
      :::
      x
      #{a}
      #{b}
      #{c}
      #{alpha}
      #{beta}
      #{gamma}
    }
    EOS
end

private def mae_one_atom : String
  <<-EOS
    m_atom[1] {
      i_m_atomic_number
      r_m_x_coord
      r_m_y_coord
      r_m_z_coord
      :::
      1 6 0 0 0
      :::
    }
    EOS
end

private def with_gzip_mae(suffix : String, & : String ->)
  content = File.read(spec_file("plain.mae"))
  path = File.tempname("plain", suffix)
  begin
    File.open(path, "w") do |file|
      Compress::Gzip::Writer.open(file, &.print(content))
    end
    yield path
  ensure
    File.delete?(path)
  end
end
