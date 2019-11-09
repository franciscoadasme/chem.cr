module Chem::PDB
  @[IO::FileType(format: PDB, ext: [:pdb])]
  class Builder < IO::Builder
    PDB_VERSION      = "3.30"
    PDB_VERSION_DATE = Time.local 2011, 7, 13

    setter bonds : Bool | Array(Bond)
    setter experiment : Structure::Experiment?
    property? renumber : Bool
    setter title = ""

    @atom_index_table : Hash(Int32, Int32)?

    def initialize(@io : ::IO,
                   @bonds : Bool | Array(Bond) = false,
                   @renumber : Bool = true)
      @atom_index = 0
    end

    def bonds : Nil
      return unless (bonds = @bonds).is_a?(Array(Bond))

      idx_pairs = Array(Tuple(Int32, Int32)).new bonds.size
      bonds.each do |bond|
        i = bond.first.serial
        j = bond.second.serial
        i, j = atom_index_table[i], atom_index_table[j] if renumber?
        bond.order.clamp(1..3).times do
          idx_pairs << {i, j} << {j, i}
        end
      end

      idx_pairs.sort!.chunk(&.[0]).each do |i, pairs|
        pairs.each_slice(4, reuse: true) do |slice|
          @io << "CONECT"
          Hybrid36.encode @io, i, width: 5
          slice.each { |pair| Hybrid36.encode @io, pair[1], width: 5 }
          @io.puts
        end
      end
    end

    def bonds? : Bool
      @bonds == true
    end

    def document_footer : Nil
      string "END", width: 80
      newline
    end

    def document_header : Nil
      @experiment.try &.to_pdb(self)
      title @title unless @experiment || @title.blank?
      pdb_version
    end

    def index(atom : Atom) : Int32
      idx = next_index
      atom_index_table[atom.serial] = idx if @bonds
      idx
    end

    def object_footer : Nil
      bonds
    end

    def pdb_version : Nil
      string "REMARK"
      space
      number 4, width: 3
      space 70
      newline

      string "REMARK"
      space
      number 4, width: 3
      space
      string (@experiment.try(&.pdb_accession.upcase) || ""), width: 4
      string " COMPLIES WITH FORMAT V. "
      string PDB_VERSION, width: 4
      string ','
      space
      PDB_VERSION_DATE.to_pdb self
      space 25
      newline
    end

    def ter(residue : Residue) : Nil
      string "TER", width: 6
      renumber? ? number(next_index, width: 5) : space(5)
      space 6
      string residue.name, width: 3
      space
      string residue.chain.id
      number residue.number, width: 4
      string residue.insertion_code || ' '
      space 53
      newline
    end

    def title(str : String) : Nil
      str.scan(/.{1,70}( |$)/).each_with_index do |match, i|
        string "TITLE", width: 6
        space 2
        if i > 0
          number i + 1, width: 2
          space
          string match[0].strip, width: 69
        else
          space 2
          string match[0].strip, width: 70
        end
        newline
      end
    end

    private def atom_index_table : Hash(Int32, Int32)
      @atom_index_table ||= {} of Int32 => Int32
    end

    private def next_index : Int32
      @atom_index += 1
    end
  end
end
