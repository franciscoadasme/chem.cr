@[Chem::RegisterFormat(ext: %w(.mol2))]
module Chem::Mol2
  class Writer
    include FormatWriter(AtomCollection)
    include FormatWriter::MultiEntry(AtomCollection)

    @atom_table = {} of Atom => Int32
    @res_table = {} of Residue => Int32

    protected def encode_entry(obj : AtomCollection) : Nil
      reset_index
      write_header obj.is_a?(Structure) ? obj.title : "",
        obj.n_atoms,
        obj.bonds.size,
        obj.is_a?(Structure) ? obj.n_residues : obj.each_atom.map(&.residue).uniq.sum { 1 }
      section "atom" { obj.each_atom { |atom| write atom } }
      section "bond" { obj.bonds.each_with_index { |bond, i| write bond, i + 1 } }
      section "substructure" { obj.each_residue { |res| write res } } if obj.is_a?(Structure)
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

    private def write(residue : Residue)
      @io.printf "%4d %-3s%-4d %5d %-8s %1d %1s %3s %2d\n",
        residue_index(residue),
        residue.name[..2],
        residue.number,
        1,         # root_atom
        "RESIDUE", # subst_type
        1,         # dict_type
        residue.chain.id,
        residue.name[..2],
        residue.bonds.size # inter_bonds
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

  class Reader
    include FormatReader(Structure)
    include FormatReader::MultiEntry(Structure)

    TAG          = "@<TRIPOS>"
    TAG_ATOMS    = "@<TRIPOS>ATOM"
    TAG_BONDS    = "@<TRIPOS>BOND"
    TAG_MOLECULE = "@<TRIPOS>MOLECULE"

    @builder = uninitialized Structure::Builder
    @include_charges = true
    @n_atoms = 0
    @n_bonds = 0
    @title = ""

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new @io
    end

    def skip_entry : Nil
      @pull.next_line if @pull.next_s == TAG_MOLECULE
      skip_to_tag TAG_MOLECULE
    end

    private def read_atom : Atom
      serial = @pull.next_i
      name = @pull.next_s
      coords = Spatial::Vector[@pull.next_f, @pull.next_f, @pull.next_f]
      atom_type = @pull.next_s
      symbol = atom_type[...atom_type.index('.')] # ignore sybyl type
      element = PeriodicTable[symbol]? || @pull.error("Unknown element")
      if @pull.next_token
        resid = @pull.int
        resname = @pull.next_s
        @builder.residue resname[..2], resid
        charge = @pull.next_f if @include_charges
      end
      @builder.atom name, coords, element: element, partial_charge: (charge || 0.0)
    end

    private def read_bond : Nil
      serial = @pull.next_i
      i = @pull.next_i - 1
      j = @pull.next_i - 1
      bond_type = @pull.next_s
      bond_order = case bond_type
                   when "1", "2", "3"    then bond_type.to_i
                   when "am", "ar", "du" then 1
                   else                       0
                   end
      @builder.bond i, j, bond_order, aromatic: bond_type == "ar" if bond_order > 0
    end

    private def read_header : Nil
      @pull.error("Invalid tag for structure") unless @pull.str == TAG_MOLECULE
      @pull.next_line
      @title = @pull.line.strip
      @pull.next_line
      @n_atoms = @pull.next_i
      @n_bonds = @pull.next_i
      @pull.next_line
      @pull.next_line
      @include_charges = @pull.next_s != "NO_CHARGES"
      @pull.next_line
    end

    private def decode_entry : Structure
      skip_to_tag
      raise IO::EOFError.new if @pull.eof?
      read_header
      @builder = Structure::Builder.new guess_topology: false
      @builder.title @title
      @pull.each_line do
        case @pull.str? || @pull.next_s?
        when TAG_ATOMS
          @n_atoms.times do
            @pull.next_line
            read_atom
          end
        when TAG_BONDS
          @n_bonds.times do
            @pull.next_line
            read_bond
          end
        when TAG_MOLECULE
          break
        end
      end
      @builder.build
    end

    private def skip_to_tag : Nil
      skip_to_tag TAG
    end

    private def skip_to_tag(tag : String) : Nil
      @pull.each_line do
        break if (@pull.str? || @pull.next_s?).try(&.starts_with?(tag))
      end
    end
  end
end
