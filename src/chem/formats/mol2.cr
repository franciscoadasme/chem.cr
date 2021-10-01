@[Chem::RegisterFormat(ext: %w(.mol2))]
module Chem::Mol2
  class Reader
    include FormatReader(Structure)
    include FormatReader::MultiEntry(Structure)

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new @io
    end

    def skip_entry : Nil
      @pull.next_line if @pull.next_s == "@<TRIPOS>MOLECULE"
      skip_to_tag "@<TRIPOS>MOLECULE"
    end

    private def decode_entry : Structure
      skip_to_tag "@<TRIPOS>MOLECULE"
      @pull.next_line
      raise IO::EOFError.new if @pull.eof?

      title = @pull.line.strip
      @pull.next_line
      n_atoms = @pull.next_i
      n_bonds = @pull.next_i
      @pull.next_line
      @pull.next_line
      include_charges = @pull.next_s != "NO_CHARGES"
      @pull.next_line

      Structure.build(
        source_file: (file = @io).is_a?(File) ? file.path : nil
      ) do |builder|
        builder.title title
        @pull.each_line do
          case @pull.str? || @pull.next_s?
          when "@<TRIPOS>ATOM"
            n_atoms.times do
              @pull.next_line
              serial = @pull.next_i
              name = @pull.next_s
              coords = Spatial::Vector[@pull.next_f, @pull.next_f, @pull.next_f]
              atom_type = @pull.next_s
              symbol = atom_type[...atom_type.index('.')] # ignore sybyl type
              element = PeriodicTable[symbol]? || @pull.error("Unknown element")
              if @pull.next_token
                resid = @pull.int
                resname = @pull.next_s
                builder.residue resname[..2], resid
                chg = @pull.next_f if include_charges
              end
              builder.atom name, coords, element: element, partial_charge: (chg || 0.0)
            end
          when "@<TRIPOS>BOND"
            n_bonds.times do
              @pull.next_line
              @pull.next_token # skip bond index
              i = @pull.next_i - 1
              j = @pull.next_i - 1
              case bond_t = @pull.next_s
              when "1", "2", "3"
                builder.bond i, j, order: bond_t.to_i
              when "ar"
                builder.bond i, j, aromatic: true
              when "am", "du"
                builder.bond i, j
              end
            end
          when "@<TRIPOS>CRYSIN"
            @pull.next_line
            size = Spatial::Size.new(@pull.next_f, @pull.next_f, @pull.next_f)
            alpha = @pull.next_f
            beta = @pull.next_f
            gamma = @pull.next_f
            builder.lattice Lattice.new(size, alpha, beta, gamma)
          when "@<TRIPOS>MOLECULE"
            break
          end
        end
      end
    end

    private def skip_to_tag(tag : String) : Nil
      @pull.each_line do
        break if (@pull.str? || @pull.next_s?) == tag
      end
    end
  end

  class Writer
    include FormatWriter(AtomCollection)
    include FormatWriter::MultiEntry(AtomCollection)

    @atom_table = {} of Atom => Int32
    @res_table = {} of Residue => Int32

    protected def encode_entry(obj : AtomCollection) : Nil
      reset_index
      raise Error.new("Structure has no bonds") if obj.bonds.empty?
      write_header obj.is_a?(Structure) ? obj.title : "",
        obj.n_atoms,
        obj.bonds.size,
        obj.is_a?(Structure) ? obj.n_residues : obj.each_atom.map(&.residue).uniq.sum { 1 }
      section "atom" { obj.each_atom { |atom| write atom } }
      section "bond" { obj.bonds.each_with_index { |bond, i| write bond, i + 1 } }
      section "substructure" do
        obj.each_residue do |residue|
          root_atom = residue.protein? ? residue.dig("CA") : residue.atoms[0]
          @io.printf "%4d %-8s %5d %-8s %1s %1s %3s\n",
            residue_index(residue),
            "#{residue.name[..2]}#{residue.number}", # subst_name
            atom_index(root_atom),                   # root atom
            "RESIDUE",                               # subst_type
            residue.protein? ? 1 : '*',              # dict_type
            residue.chain.id,                        # chain
            residue.name[..2]                        # sub_type
        end
      end
      if (structure = obj.as?(Structure)) && (cell = structure.lattice)
        section "crysin" do
          formatl "%.3f %.3f %.3f %.2f %.2f %.2f 1 1",
            cell.a, cell.b, cell.c, cell.alpha, cell.beta, cell.gamma
        end
      end
    end

    private def atom_index(atom : Atom) : Int32
      @atom_table[atom] ||= @atom_table.size + 1
    end

    private def reset_index
      @atom_table.clear
      @res_table.clear
    end

    private def residue_index(residue : Residue) : Int32
      @res_table[residue] ||= @res_table.size + 1
    end

    private def section(name : String, &block : ->)
      @io << "@<TRIPOS>" << name.upcase << '\n'
      yield
      @io.puts
    end

    private def write(atom : Atom)
      @io.printf "%5d %-4s%10.4f%10.4f%10.4f %-4s%4d %3s%-4d%8.4f\n",
        atom_index(atom),
        atom.name,
        atom.x,
        atom.y,
        atom.z,
        atom.element.symbol,
        residue_index(atom.residue),
        atom.residue.name,
        atom.residue.number,
        atom.partial_charge
    end

    private def write(bond : Bond, i : Int32)
      @io.printf "%5d%5d%5d%2d\n",
        i,
        atom_index(bond.first),
        atom_index(bond.second),
        bond.order
    end

    private def write_header(title, n_atoms, n_bonds, n_residues)
      section "molecule" do
        @io.puts title.gsub(/ *\n */, ' ')
        @io.printf "%5d%5d%4d\n", n_atoms, n_bonds, n_residues
        @io.puts "UNKNOWN"
        @io.puts "USER_CHARGES"
      end
    end
  end
end
