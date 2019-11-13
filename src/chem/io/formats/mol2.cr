module Chem::Mol2
  enum RecordType
    Molecule
    Atom
    Bond
  end

  @[IO::FileType(format: Mol2, ext: [:mol2])]
  class Builder < IO::Builder
    setter atoms = 0
    setter bonds = 0
    setter residues = 0
    setter title = ""

    def initialize(@io : ::IO)
      @atom_index_table = {} of Int32 => Int32
      @bond_index = 0
      @resnum_table = {} of Int32 => Int32
    end

    def atom_index(atom : Atom) : Int32
      @atom_index_table[atom.serial] ||= @atom_index_table.size + 1
    end

    def next_bond_index : Int32
      @bond_index += 1
    end

    def residue_index(residue : Residue) : Int32
      @resnum_table[residue.number] ||= @resnum_table.size + 1
    end

    def object_header : Nil
      @atom_index_table.clear
      @bond_serial = 0
      @resnum_table.clear

      section "molecule" do
        string @title
        newline
        number @atoms, width: 5
        number @bonds, width: 5
        number @residues, width: 4
        newline
        string "UNKNOWN"
        newline
        string "USER_CHARGES"
        newline
      end
    end

    def section(name : String, &block : ->) : Nil
      string "@<TRIPOS>"
      string name.upcase
      newline
      yield
      newline
    end
  end

  @[IO::FileType(format: Mol2, ext: [:mol2])]
  class Parser < IO::Parser
    include IO::PullParser

    def next : Structure | Iterator::Stop
      skip_to_record :molecule
      eof? ? stop : parse
    end

    def skip_structure : Nil
      skip_line if record? :molecule
      skip_to_record :molecule
    end

    private def guess_bond_order(bond_type : String) : Int32
      case bond_type
      when "am", "ar", "du"
        1
      when "un", "nc"
        0
      else
        bond_type.to_i
      end
    end

    private def parse : Structure
      Structure.build do |builder|
        skip_line
        builder.title read_line.strip
        n_atoms = read_int
        n_bonds = read_int
        skip_line

        while name = next_record
          case name
          when .atom?
            n_atoms.times { parse_atom builder }
          when .bond?
            n_bonds.times { parse_bond builder }
          when .molecule?
            @io.pos = @prev_pos
            break
          end
        end
      end
    end

    private def next_record : RecordType?
      until eof?
        if record_type = read_record
          return record_type
        else
          skip_line
        end
      end
    end

    private def parse_atom(builder : Topology::Builder) : Nil
      skip_whitespace
      skip_index
      name = scan_in_set "a-zA-Z0-9"
      coords = read_vector
      element = read_element
      skip('.').skip_in_set("A-z0-9").skip_spaces # skip atom type
      unless check(&.whitespace?)
        resid = read_int
        resname = skip_spaces.scan_in_set "A-z0-9"
        builder.residue resname[..2], resid
      end
      charge = read_float unless skip_spaces.check(&.whitespace?)
      skip_line
      builder.atom name, coords, element: element, partial_charge: (charge || 0.0)
    end

    private def parse_bond(builder : Topology::Builder) : Nil
      skip_index
      i = read_int - 1
      j = read_int - 1
      bond_type = skip_spaces.scan(/[a-z0-9]+/).to_s
      bond_order = guess_bond_order bond_type
      builder.bond i, j, bond_order, aromatic: bond_type == "ar" if bond_order > 0
      skip_line
    end

    private def read_element : Element
      PeriodicTable[skip_spaces.scan_in_set("A-z")]
    end

    private def read_record : RecordType?
      skip_whitespace
      return unless check "@<TRIPOS>"
      name = read { skip(9).read_line.rstrip.downcase }
      RecordType.parse? name
    end

    private def record?(type : RecordType) : Bool
      if record_type = read_record
        @io.pos = @prev_pos
        record_type == type
      else
        false
      end
    end

    private def skip_index : self
      skip_spaces.skip_in_set("0-9").skip_spaces
    end

    private def skip_to_record(type : RecordType) : Nil
      until eof?
        break if record? type
        skip_line
      end
    end
  end

  def self.build(**options) : String
    String.build do |io|
      build(io, **options) do |mol2|
        yield mol2
      end
    end
  end

  def self.build(io : ::IO, **options) : Nil
    builder = Builder.new io, **options
    builder.document do
      yield builder
    end
  end
end

module Chem
  class Atom
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.number mol2.atom_index(self), width: 5
      mol2.space
      mol2.string name, width: 4
      coords.to_mol2 mol2
      mol2.space
      element.to_mol2 mol2 # atom_type
      mol2.number mol2.residue_index(residue), width: 4
      mol2.space
      mol2.string residue.name, width: 3
      mol2.number residue.number, alignment: :left, width: 4
      mol2.number partial_charge, precision: 4, width: 8
      mol2.newline
    end
  end

  module AtomCollection
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.atoms = n_atoms
      mol2.bonds = bonds.size
      mol2.residues = n_residues
      mol2.title = title

      mol2.object do
        mol2.section "atom" { each_atom &.to_mol2(mol2) }
        mol2.section "bond" { bonds.each &.to_mol2(mol2) }
        mol2.section "substructure" { each_residue &.to_mol2(mol2) }
      end
    end
  end

  class Bond
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.number mol2.next_bond_index, width: 5
      mol2.number mol2.atom_index(first), width: 5
      mol2.number mol2.atom_index(second), width: 5
      mol2.number order, width: 2
      mol2.newline
    end
  end

  class Element
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.string @symbol, width: 4
    end
  end

  class Residue
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.number mol2.residue_index(self), width: 4
      mol2.space
      mol2.string name[..2], width: 3
      mol2.number number, alignment: :left, width: 4
      mol2.space
      mol2.number 1, width: 5 # root_atom
      mol2.space
      mol2.string "RESIDUE" # subst_type
      mol2.space
      mol2.number 1 # dict_type
      mol2.space
      mol2.string chain.id
      mol2.space
      mol2.string name[..2], width: 3
      mol2.space
      mol2.number 1 # inter_bonds
    end
  end

  struct Spatial::Vector
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.number x, precision: 4, width: 10
      mol2.number y, precision: 4, width: 10
      mol2.number z, precision: 4, width: 10
    end
  end
end
