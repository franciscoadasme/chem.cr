require "./from_pdb"
require "./record"
require "../topology/templates/all"

module Chem::PDB
  class Parser
    @atoms_by_serial = {} of Int32 => Atom
    @bonds = Hash(Tuple(Int32, Int32), Int32).new default_value: 0
    @current_atom : Atom?
    @current_chain : Chain?
    @current_record : Record
    @current_residue : Residue?
    @current_system : System
    @input : ::IO
    @line_number : Int32 = 0
    @ss_records = [] of SSRecord

    getter current_system : System

    def initialize(@input : ::IO)
      @current_record = uninitialized Record
      @current_system = uninitialized System
    end

    def current_chain : Chain
      @current_chain.not_nil!
    end

    def current_residue : Residue
      @current_residue.not_nil!
    end

    def fail(msg : String)
      column_number = @current_record.last_read_range.begin
      raise ParseException.new "#{msg} at #{@line_number}:#{column_number}"
    end

    def next_index
      (@current_atom.try(&.index) || -1) + 1
    end

    def next_residue_index
      return 0 unless @current_residue
    end

    def next_record : Record
      @line_number += 1
      @current_record = Record.new @input.read_line
    end

    def next_record_while(name : String, &block)
      next_record_while [name], &block
    end

    def next_record_while(names : Array(String))
      pos = @input.pos
      yield
      while names.includes? next_record.name
        pos = @input.pos
        yield
      end
      @line_number -= 1
      @input.pos = pos
    end

    def parse : System
      @current_system = System.new
      until next_record.name == "end"
        parse_current_record
      end
      assign_bonds
      assign_secondary_structure
      @current_system
    end

    def read_char(index : Int) : Char
      @current_record[index]
    end

    def read_chars(range : Range(Int, Int)) : String
      @current_record[range]
    end

    def read_chars(range : Range(Int, Int), *, if_blank value : T) : String | T forall T
      chars = read_chars range
      chars.blank? ? value : chars
    end

    def read_chars?(range, **options) : String?
      read_chars range, **options
    rescue IndexError
      nil
    end

    def read_date(range : Range(Int, Int)) : Time
      Time.parse_utc read_chars(range), "%d-%^b-%y"
    end

    def read_float(range : Range(Int, Int)) : Float64
      read_chars(range).to_f
    end

    def read_float?(range : Range(Int, Int)) : Float64?
      read_chars(range).to_f?
    end

    def read_formal_charge : Int32
      chars = read_chars?(78..79, if_blank: nil)
      chars ? chars.reverse.to_i : 0
    rescue ArgumentError
      fail "Couldn't read a formal charge"
    end

    def read_int(range : Range(Int, Int), base : Int32 = 10) : Int32
      read_chars(range).to_i base
    end

    def read_residue_number : Int32
      current_resnum = @current_residue.try(&.number) || 0
      resnum = read_chars 22..25
      return guess_residue_number if resnum == "****"
      resnum.to_i base: current_resnum < 9999 || resnum == "9999" ? 10 : 16
    end

    def read_serial : Int32
      chars = read_chars 6..10
      current_serial = @current_atom.try(&.serial) || 0
      return current_serial + 1 if chars == "*****"
      chars.to_i base: current_serial < 99999 ? 10 : 16
    rescue ArgumentError
      fail "Couldn't read serial number"
    end

    def read_title : String
      String.build do |builder|
        next_record_while name: "title" do
          builder << read_chars(10..-1).rstrip
        end
      end.squeeze ' '
    end

    def record_name : String
      @current_record.name
    end

    private def assign_bonds
      @bonds.each do |serials, bond_order|
        atom1 = @atoms_by_serial[serials[0]]
        atom2 = @atoms_by_serial[serials[1]]
        atom1.bonds.add atom2, Bond::Kind.from_value(bond_order)
      end
    end

    private def assign_secondary_structure
      @ss_records.each do |rcd|
        chain = @current_system.each_chain.select { |chain| chain.id == rcd.chain }.first
        chain.each_residue do |residue|
          residue.secondary_structure = rcd.kind if rcd.range.includes?(residue.number)
        end
      end
    end

    private def guess_residue_number : Int32
      resname = read_chars(17..20).strip
      residue = @current_residue.not_nil!

      next_number = residue.number
      if residue.name == resname
        if template = Topology::Templates[resname]?
          atom_name = read_chars(12..15).strip
          count = template.atom_count include_hydrogens: atom_name.starts_with?('H')
          next_number += 1 unless residue.atoms.size < count
        end
      else
        next_number += 1
      end
      next_number
    end

    private def parse_atom_record
      update_chain
      update_residue
      atom = Atom.new self
      @current_atom = atom
      @atoms_by_serial[atom.serial] = atom
      current_residue << atom
    end

    private def parse_bonds
      serial = read_int 6..10
      {11..15, 16..20, 21..25, 26..30}.each do |range|
        if other = read_chars?(range, if_blank: nil).try(&.to_i)
          next if @bonds.has_key?({other, serial}) # skip redundant bonds
          @bonds[{serial, other}] += 1             # parse duplicates as bond order
        else
          break # there are no more indices to read
        end
      end
    end

    private def parse_current_record
      case record_name
      when "atom", "hetatm"
        parse_atom_record
      when "conect"
        parse_bonds
      when "cryst1"
        @current_system.lattice = Lattice.new self
      when "header"
        expt = Protein::Experiment.new self
        @current_system.experiment = expt
        @current_system.title = expt.pdb_accession
      when "helix", "sheet"
        @ss_records << SSRecord.new self
      when "seqres"
        @current_system.sequence = Protein::Sequence.new self
      when "title"
        @current_system.title = read_title
      end
    end

    private def update_chain
      chain_id, new_id = @current_chain.try(&.id), read_char 21
      return if chain_id == new_id

      chain = @current_system.chains[new_id]?
      @current_system << (chain = Chain.new self) unless chain
      @current_chain = chain
    end

    private def update_residue
      res = @current_residue
      resnum = read_residue_number
      if res.try(&.chain.id) != current_chain.id || res.try(&.number) != resnum
        current_chain << (residue = Residue.new self)
        @current_residue = residue
      end
    end
  end
end
