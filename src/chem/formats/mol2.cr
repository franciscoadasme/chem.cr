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
        guess_bonds: false,
        guess_names: false,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
        use_templates: false,
      ) do |builder|
        builder.title title
        @pull.each_line do
          case @pull.str? || @pull.next_s?
          when "@<TRIPOS>ATOM"
            n_atoms.times do
              @pull.next_line
              serial = @pull.next_i
              name = @pull.next_s
              coords = Spatial::Vec3[@pull.next_f, @pull.next_f, @pull.next_f]
              atom_t = @pull.next_s
              symbol = atom_t[...atom_t.index('.')] # ignore sybyl type
              element = PeriodicTable[symbol]? || @pull.error("Unknown element")
              unless @pull.next_token.eol?
                resid = @pull.int
                resname = @pull.next_s
                # TODO: respect name or truncate at 4 characters?
                builder.residue resname[..2], resid
                chg = @pull.next_f if include_charges
              end
              builder.atom name, coords, element: element, partial_charge: (chg || 0.0)
            end
          when "@<TRIPOS>BOND"
            n_bonds.times do
              @pull.next_line
              @pull.next_token # skip bond index
              i = @pull.next_i
              j = @pull.next_i
              case bond_t = @pull.next_s
              when "1", "2", "3"
                builder.bond i, j, BondOrder.from_value(bond_t.to_i)
              when "ar"
                builder.bond i, j, aromatic: true
              when "am", "du"
                builder.bond i, j
              end
            end
          when "@<TRIPOS>CRYSIN"
            @pull.next_line
            x = @pull.next_f
            @pull.error "Invalid size" unless x > 0
            y = @pull.next_f
            @pull.error "Invalid size" unless y > 0
            z = @pull.next_f
            @pull.error "Invalid size" unless z > 0
            alpha = @pull.next_f
            @pull.error "Invalid angle" unless 0 < alpha <= 180
            beta = @pull.next_f
            @pull.error "Invalid angle" unless 0 < beta <= 180
            gamma = @pull.next_f
            @pull.error "Invalid angle" unless 0 < gamma <= 180
            builder.cell Spatial::Parallelepiped.new({x, y, z}, {alpha, beta, gamma})
          when "@<TRIPOS>MOLECULE"
            break
          end
        end
      end
        .tap &.topology.guess_formal_charges
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
      if (structure = obj.as?(Structure)) && (cell = structure.cell?)
        section "crysin" do
          a, b, c = cell.size
          alpha, beta, gamma = cell.angles
          formatl "%.3f %.3f %.3f %.2f %.2f %.2f 1 1", a, b, c, alpha, beta, gamma
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
        atom_index(bond.atoms[0]),
        atom_index(bond.atoms[1]),
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
