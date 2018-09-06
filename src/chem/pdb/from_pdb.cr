require "../topology/atom.cr"
require "../lattice.cr"
require "../periodic_table"
require "../protein"
require "../geometry/vector.cr"
require "./parser"

module Chem
  class Atom
    def initialize(pull : PDB::Parser)
      @charge = pull.read_formal_charge
      @coords = Geometry::Vector.new pull
      @element = PeriodicTable::Element.new pull
      @index = pull.next_index
      @name = pull.read_chars(12..15).strip
      @occupancy = pull.read_float 54..59
      @residue = pull.current_residue
      @serial = pull.read_serial
      @temperature_factor = pull.read_float 60..65
    end
  end

  class Chain
    def initialize(pull : PDB::Parser)
      @identifier = pull.read_char 21
      @system = pull.current_system
    end
  end

  struct Geometry::Vector
    def initialize(pull : PDB::Parser)
      @x = pull.read_float 30..37
      @y = pull.read_float 38..45
      @z = pull.read_float 46..53
    end
  end

  def Lattice.new(pull : PDB::Parser) : Lattice
    new size: {pull.read_float(6..14),
               pull.read_float(15..23),
               pull.read_float(24..32)},
      angles: {pull.read_float(33..39),
               pull.read_float(40..46),
               pull.read_float(47..53)},
      space_group: pull.read_chars(55..65).rstrip
    #  z: pull.read_int(4)
  end

  def PeriodicTable::Element.new(pull : PDB::Parser) : PeriodicTable::Element
    if symbol = pull.read_chars? 76..77, if_blank: nil
      PeriodicTable[symbol.lstrip]
    else
      PeriodicTable.element atom_name: pull.read_chars(12..15).strip
    end
  rescue PeriodicTable::UnknownElement
    # pull.fail "Couldn't determine element of atom #{pull.read_chars 12..15}"
    raise "Couldn't determine element of atom #{pull.read_chars(12..15).strip}"
  end

  struct Protein::Experiment
    def initialize(pull : PDB::Parser)
      @deposition_date = Time.now
      @pdb_accession = "0000"
      @title = ""

      names = ["header", "obslte", "title", "split", "caveat", "compnd", "source",
               "keywds", "expdta", "nummdl", "mdltyp", "author", "revdat", "sprsde",
               "jrnl", "remark"]
      pull.next_record_while names do
        case pull.record_name
        when "expdta"
          @kind = Kind.parse pull.read_chars(10..-1).strip.delete "- "
        when "header"
          @deposition_date = pull.read_date 50..58
          @pdb_accession = pull.read_chars(62..65).downcase
        when "jrnl"
          case pull.read_chars(12..15).rstrip.downcase
          when "doi"
            @doi = pull.read_chars(19..-1).rstrip
          end
        when "remark"
          next if pull.read_chars(10..-1).blank? # skip remark first line
          case pull.read_int 7..9
          when 2
            @resolution = pull.read_float? 23..29
          end
        when "title"
          @title = pull.read_title
        end
      end
    end
  end

  struct Protein::Sequence
    def initialize(pull : PDB::Parser)
      pull.next_record_while name: "seqres" do
        pull.read_chars(19..-1).split.each do |name|
          @aminoacids << Protein::AminoAcid[name]
        end
      end
    end
  end

  class Residue
    def initialize(pull : PDB::Parser)
      @name = pull.read_chars(17..20).strip
      @number = pull.read_residue_number
      @chain = pull.current_chain
    end
  end
end
