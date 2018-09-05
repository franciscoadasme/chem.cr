require "../geometry/vector"
require "../io/pull_parser"
require "../lattice"
require "../protein/experiment"
require "../protein/sequence"
require "../system"
require "../topology/atom"
require "../topology/residue"

module Chem::PDB
  class PullParser
    include IO::PullParser

    @atom_index : Int32 = -1
    @prev_residue_num : Int32 = 0
    @prev_serial : Int32 = 0
    @record_type : RecordType = :unknown

    def at_record_end?
      peek_char == '\n'
    end

    def current_index : Int32
      @atom_index
    end

    def next_record : RecordType
      skip_line if @input.pos > 0 && prev_char != '\n'
      @record_type = read_record_type
    end

    def parse : System
      System.new self
    end

    def read_atom : Atom
      @atom_index += 1
      Atom.new self
    end

    def read_coords : Geometry::Vector
      Geometry::Vector.new self
    end

    def read_date : Time
      Time.parse_utc read_chars(9), "%d-%^b-%y"
    end

    def read_experiment : Protein::Experiment
      rewind_to_beginning_of_record
      Protein::Experiment.new self
    end

    def read_experiment_kind : Protein::Experiment::Kind
      Protein::Experiment::Kind.parse read_line.strip.delete "- "
    rescue ArgumentError
      fail "Couldn't determine experimental technique"
    end

    def read_formal_charge : Int32
      return 0 if at_record_end?
      if chars = read_chars_or_null 2, stop_at: '\n'
        chars.reverse.to_i
      else
        0
      end
    rescue ArgumentError
      fail "Couldn't read a formal charge"
    end

    def read_lattice : Lattice
      Lattice.new self
    end

    def read_or_guess_element(atom_name : String) : PeriodicTable::Element
      symbol = read_chars(2, stop_at: '\n').lstrip unless at_record_end?
      element = PeriodicTable[symbol]? if symbol
      element || PeriodicTable.element atom_name: atom_name
    rescue PeriodicTable::UnknownElement
      fail "Couldn't determine element of atom #{atom_name}"
    end

    def read_residue : Residue
      rewind_to_beginning_of_record
      skip_record_type
      Residue.new self
    end

    # TODO need to handle **** (cannot simply return @prev_residue_num += 1)
    def read_residue_number : Int32
      base = if @prev_residue_num < 9999
               10
             elsif @prev_residue_num == 9999 && peek_char == '9' # still resid 9999
               10
             else
               16
             end
      @prev_residue_num = read_chars(4).to_i base
    rescue ArgumentError
      fail "Couldn't read residue number"
    end

    # TODO need to handle ***** (return @prev_serial += 1)
    def read_serial : Int32
      base = @prev_serial < 99999 ? 10 : 16
      @prev_serial = read_chars(5).to_i base
    rescue ArgumentError
      fail "Couldn't read serial number"
    end

    def read_sequence : Protein::Sequence
      rewind_to_beginning_of_record
      seq = Protein::Sequence.new self
      rewind_to_beginning_of_record
      seq
    end

    def read_title : String
      title = skip_chars(4).read_line.strip
      while next_record == RecordType::Title
        title += skip_chars(4).read_line.rstrip
      end
      rewind_to_beginning_of_record
      title.squeeze ' '
    end

    private def read_record_type : RecordType
      RecordType.parse read_chars(6).rstrip
    rescue ::IO::EOFError
      RecordType::End
    end

    private def skip_record_type : self
      skip_chars 6
      self
    end

    private def rewind_to_beginning_of_record : Nil
      rewind { |char| char != '\n' }
    end
  end
end
