module Chem::Mol2
  @[IO::FileType(format: Mol2, ext: [:mol2])]
  class PullParser < IO::Parser
    include IO::PullParser

    def initialize(input : ::IO | Path | String)
      super
      @builder = Structure::Builder.new
      @n_atoms = @n_bonds = 0
    end

    def each_structure(&block : Structure ->)
      yield parse
    end

    def each_structure(indexes : Indexable(Int), &block : Structure ->)
      yield parse if indexes.size == 1 && indexes == 0
    end

    def parse : Structure
      until eof?
        skip_whitespace
        check('@') ? parse_record : skip_line
      end
      @builder.build
    end

    def skip_index : self
      skip_spaces.skip_in_set("0-9").skip_spaces
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

    private def parse_atoms : Nil
      @n_atoms.times do
        skip_whitespace
        @builder.atom self
        skip_line
      end
    end

    private def parse_bonds : Nil
      atoms = @builder.build.atoms
      aromatic_bonds = [] of Bond
      @n_bonds.times do
        skip_index
        atom = atoms[read_int - 1]
        other = atoms[read_int - 1]
        bond_type = skip_spaces.scan(/[a-z0-9]+/).to_s
        bond_order = guess_bond_order bond_type
        if bond_order > 0
          bond = Bond.new atom, other, bond_order
          atom.bonds.add bond
          aromatic_bonds << bond if bond_type == "ar"
        end
        skip_line
      end
      transform_aromatic_bonds aromatic_bonds
    end

    private def parse_header : Nil
      @builder.title read_line.strip
      @n_atoms = read_int
      @n_bonds = read_int
      3.times { skip_line }                # rest of line, mol_type, charge_type
      skip_line unless check &.whitespace? # status_bits
      skip_line unless check &.whitespace? # comment
    end

    private def parse_record : Nil
      parse_exception "Invalid record header" unless check "@<TRIPOS>"
      skip 9 # @<TRIPOS>
      case read_line.downcase
      when "atom"
        parse_atoms
      when "bond"
        parse_bonds
      when "molecule"
        parse_header
      end
    end

    private def transform_aromatic_bonds(bonds : Array(Bond))
      bonds.sort_by! { |bond| Math.min bond[0].serial, bond[1].serial }
      until bonds.empty?
        bond = bonds.shift
        if other = bonds.find { |b| b.includes?(bond[0]) || b.includes?(bond[1]) }
          bonds.delete other
          (bond[1] != other[0] ? bond : other).order = 2
        end
      end
    end
  end
end
