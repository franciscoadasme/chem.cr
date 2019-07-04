module Chem::PDB
  @[IO::FileType(format: PDB, ext: [:pdb])]
  class Builder < IO::Builder
    PDB_VERSION      = "3.30"
    PDB_VERSION_DATE = Time.new 2011, 7, 13

    property? alternate_locations : Bool
    setter bonds : Bool | Array(Bond)
    setter experiment : Protein::Experiment?
    setter title = ""

    def initialize(@io : ::IO,
                   @bonds : Bool | Array(Bond) = false,
                   @alternate_locations : Bool = true)
    end

    def bonds : Nil
      return unless (bonds = @bonds).is_a?(Array(Bond))

      idx_pairs = Array(Tuple(Int32, Int32)).new bonds.size
      bonds.each do |bond|
        bond.order.clamp(1..3).times do
          idx_pairs << {bond.first.serial, bond.second.serial}
          idx_pairs << {bond.second.serial, bond.first.serial}
        end
      end
      idx_pairs.sort!.chunk(&.[0]).each do |i, pairs|
        pairs.each_slice(4, reuse: true) do |slice|
          @io.printf "CONECT%5d", i
          slice.each { |pair| @io.printf "%5d", pair[1] }
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
      space 5
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
  end
end
