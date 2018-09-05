require "../topology/atom.cr"
require "../lattice.cr"
require "../periodic_table"
require "../protein"
require "../geometry/vector.cr"
require "./pull_parser"

module Chem
  class Atom
    def initialize(pull : PDB::PullParser)
      @index = pull.current_index
      @serial = pull.read_serial
      pull.skip_char
      @name = pull.read_chars(4).strip
      @altloc = pull.read_char_or_null
      @residue_name = pull.read_chars(4).strip
      @chain = pull.read_char_or_null
      @residue_number = pull.read_residue_number
      @insertion_code = pull.read_char_or_null
      pull.skip_chars 3
      @coords = pull.read_coords
      @occupancy = pull.read_float 6
      @temperature_factor = pull.read_float 6
      pull.skip_chars 10, stop_at: '\n'
      @element = pull.read_or_guess_element @name
      @charge = pull.read_formal_charge
    end
  end

  struct Protein::Experiment
    def initialize(pull : PDB::PullParser)
      @deposition_date = Time.now
      @pdb_accession = "0000"
      @title = ""

      loop do
        case pull.next_record
        when .citation?
          pull.skip_chars 6
          field_name = pull.read_chars(4).rstrip.downcase
          pull.skip_chars 3
          case field_name
          when "doi"
            @doi = pull.read_line.rstrip
          end
        when .experiment?
          @kind = pull.read_experiment_kind
        when .header?
          pull.skip_chars 4
          pull.skip_chars 40 # molecule classification
          @deposition_date = pull.read_date
          pull.skip_chars 3
          @pdb_accession = pull.read_chars(4).downcase
        when .remark?
          pull.skip_char
          number = pull.read_int 3
          pull.skip_char
          next if pull.peek_line.blank? # skip remark first line
          case number
          when 2
            pull.skip_chars 12
            @resolution = pull.read_float 7
            break # must break loop after reading the last field
          end
        when .title?
          @title = pull.read_title
        end
      end
    end
  end

  def Lattice.new(pull : PDB::PullParser) : Lattice
    new size: {pull.read_float(9), pull.read_float(9), pull.read_float(9)},
      angles: {pull.read_float(7), pull.read_float(7), pull.read_float(7)},
      space_group: pull.skip_char.read_chars(11).rstrip
    #  z: pull.read_int(4)
  end

  struct Protein::Sequence
    def initialize(pull : PDB::PullParser)
      @aminoacids = [] of Protein::AminoAcid

      while pull.next_record.sequence?
        pull.skip_chars 5
        chain = pull.read_char
        pull.skip_chars 7
        pull.read_line.split.each do |name|
          @aminoacids << Protein::AminoAcid[name]
        end
      end
    end
  end

  class System
    def initialize(pull : PDB::PullParser)
      @title = ""
      @atoms = [] of Atom

      loop do
        case pull.next_record
        when .atom?
          @atoms << pull.read_atom
        when .end?
          break
        when .header?
          experiment = pull.read_experiment
          @experiment = experiment
          @title = experiment.pdb_accession
        when .lattice?
          @lattice = pull.read_lattice
        when .sequence?
          @sequence = pull.read_sequence
        when .title?
          @title = pull.read_title
        else
          # puts "#{record_type} #{pull.read_line.inspect}"
        end
      end
    end
  end

  struct Geometry::Vector
    def initialize(pull : PDB::PullParser)
      @x = pull.read_float 8
      @y = pull.read_float 8
      @z = pull.read_float 8
    end
  end
end
