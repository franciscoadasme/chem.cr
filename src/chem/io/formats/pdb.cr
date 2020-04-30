module Chem::PDB
  module Hybrid36
    extend self

    def decode(str : String) : Int32?
      decode str, str.size
    end

    def decode(str : String, width : Int) : Int32
      decode?(str, width) || invalid_literal str
    end

    def decode?(str : String) : Int32?
      decode? str, str.size
    end

    def decode?(str : String, width : Int) : Int32?
      return unless str.size == width
      return 0 if str.blank?

      chr = str[0]
      return str.to_i? if chr == '-' || chr == ' ' || chr.ascii_number?
      return unless num = str.to_i?(base: 36)

      case chr
      when .ascii_uppercase? then num - 10*36**(width - 1) + 10**width
      when .ascii_lowercase? then num + 16*36**(width - 1) + 10**width
      else                        nil
      end
    end

    def encode(num : Int, width : Int) : String
      String.build do |io|
        encode io, num, width
      end
    end

    def encode(io : ::IO, num : Int, width : Int) : Nil
      out_of_range num if num < 1 - 10**(width - 1)
      return io.printf "%#{width}d", num if num < 10**width
      num -= 10**width
      return (num + 10*36**(width - 1)).to_s 36, io, upcase: true if num < 26*36**(width - 1)
      num -= 26*36**(width - 1)
      return (num + 10*36**(width - 1)).to_s 36, io if num < 26*36**(width - 1)
      out_of_range num
    end

    private def invalid_literal(str : String)
      raise ArgumentError.new "Invalid number literal: #{str}"
    end

    private def out_of_range(num : Int)
      raise ArgumentError.new "Value out of range"
    end
  end

  @[IO::FileType(format: PDB, ext: %w(ent pdb))]
  class Writer < IO::Writer(AtomCollection)
    PDB_VERSION      = "3.30"
    PDB_VERSION_DATE = Time.local 2011, 7, 13
    WHITESPACE       = ' '

    @atom_index_table = {} of Int32 => Int32
    @record_index = 0
    @model = 0

    def initialize(io : ::IO | Path | String,
                   @bonds : Bool | Array(Bond) = false,
                   @renumber : Bool = true,
                   *,
                   sync_close : Bool = false)
      super io, sync_close: sync_close
    end

    def close : Nil
      write_bonds
      @io.printf "%-80s\n", "END"
      super
    end

    def write(atoms : AtomCollection) : Nil
      check_open
      @record_index = 0
      @bonds = atoms.bonds if @bonds == true

      write_pdb_version if @model == 0

      atoms.each_atom { |atom| write atom }

      @model += 1
    end

    def write(structure : Structure) : Nil
      check_open
      @record_index = 0
      @bonds = structure.bonds if @bonds == true

      write_header structure if @model == 0

      structure.each_chain do |chain|
        p_res = nil
        chain.each_residue do |residue|
          residue.each_atom { |atom| write atom }
          p_res = residue
        end
        write_ter p_res if p_res && p_res.polymer?
      end

      @model += 1
    end

    private def index(atom : Atom) : Int32
      idx = next_index
      @atom_index_table[atom.serial] = idx if @bonds
      idx
    end

    private def next_index : Int32
      @record_index += 1
    end

    private def write(atom : Atom) : Nil
      @io.printf "%-6s%5s %4s %-4s%s%4s%1s   %8.3f%8.3f%8.3f%6.2f%6.2f          %2s%2s\n",
        (atom.residue.protein? ? "ATOM" : "HETATM"),
        PDB::Hybrid36.encode(@renumber ? index(atom) : atom.serial, width: 5),
        atom.name[..3].ljust(3),
        atom.residue.name[..3],
        atom.chain.id,
        PDB::Hybrid36.encode(atom.residue.number, width: 4),
        atom.residue.insertion_code,
        atom.x,
        atom.y,
        atom.z,
        atom.occupancy,
        atom.temperature_factor,
        atom.element.symbol,
        (sprintf("%+d", atom.formal_charge).reverse if atom.formal_charge != 0)
    end

    private def write(expt : Structure::Experiment) : Nil
      raw_method = expt.method.to_s.underscore.upcase.gsub('_', ' ').gsub "X RAY", "X-RAY"

      @io.printf "HEADER    %40s%9s   %4s              \n",
        WHITESPACE, # classification
        expt.deposition_date.to_s("%d-%^b-%y"),
        expt.pdb_accession.upcase
      write_title expt.title
      @io.printf "EXPDTA    %-70s\n", raw_method
      @io.printf "JRNL        DOI    %-61s\n", expt.doi.not_nil! if expt.doi
    end

    private def write(lattice : Lattice) : Nil
      @io.printf "CRYST1%9.3f%9.3f%9.3f%7.2f%7.2f%7.2f %-11s%4d          \n",
        lattice.a,
        lattice.b,
        lattice.c,
        lattice.alpha,
        lattice.beta,
        lattice.gamma,
        "P 1", # default space group
        1      # default Z value
    end

    private def write_bonds : Nil
      return unless (bonds = @bonds).is_a?(Array(Bond))

      idx_pairs = Array(Tuple(Int32, Int32)).new bonds.size
      bonds.each do |bond|
        i = bond.first.serial
        j = bond.second.serial
        i, j = @atom_index_table[i], @atom_index_table[j] if @renumber
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

    private def write_header(structure : Structure) : Nil
      if expt = structure.experiment
        write expt
      else
        write_title structure.title unless structure.title.blank?
      end
      write_pdb_version structure.experiment.try(&.pdb_accession)
      write structure.lattice.not_nil! if structure.periodic?
    end

    private def write_pdb_version(pdb_accession : String? = nil) : Nil
      @io.printf "REMARK   4%-70s\n", WHITESPACE
      @io.printf "REMARK   4 %4s COMPLIES WITH FORMAT V. %4s, %9s%25s\n",
        pdb_accession.try(&.upcase),
        PDB_VERSION,
        PDB_VERSION_DATE.to_s("%d-%^b-%y"),
        WHITESPACE
    end

    private def write_ter(prev_res : Residue) : Nil
      @io.printf "TER   %5d      %3s %s%4d%1s%53s\n",
        @renumber ? next_index.to_s : WHITESPACE,
        prev_res.name,
        prev_res.chain.id,
        prev_res.number,
        prev_res.insertion_code,
        WHITESPACE
    end

    private def write_title(str : String) : Nil
      str.scan(/.{1,70}( |$)/).each_with_index do |match, i|
        @io << "TITLE   "
        if i > 0
          @io.printf "%2d %-69s\n", i + 1, match[0]
        else
          @io.printf "  %-70s\n", match[0]
        end
      end
    end
  end

  @[IO::FileType(format: PDB, ext: %w(ent pdb))]
  class Parser < Structure::Parser
    include IO::ColumnBasedParser

    @pdb_bonds = Hash(Tuple(Int32, Int32), Int32).new 0
    @pdb_expt : Structure::Experiment?
    @pdb_lattice : Lattice?
    @pdb_seq : Protein::Sequence?
    @pdb_title = ""

    @alt_locs : Hash(Residue, Array(AlternateLocation))?
    @chains : Set(Char) | String | Nil
    @seek_bonds = true
    @ss_elements = [] of SecondaryStructureElement

    def initialize(input : ::IO | Path | String,
                   @alt_loc : Char? = nil,
                   chains : Enumerable(Char) | String | Nil = nil,
                   guess_topology : Bool = true,
                   @het : Bool = true)
      super input, guess_topology
      @chains = chains.is_a?(Enumerable) ? chains.to_set : chains
      parse_header
    end

    def next : Structure | Iterator::Stop
      each_record do |name|
        case name
        when "atom", "hetatm"
          return parse_model
        when "model"
          next_record
          return parse_model
        when "end", "master"
          break
        else
          nil
        end
      end
      stop
    end

    def skip_structure : Nil
      next_record if current_record == "model"
      each_record do |name|
        case name
        when "model", "conect", "end", "master"
          break
        when "endmdl"
          next_record
          break
        else
          nil
        end
      end
    end

    private def add_sec(type : Protein::SecondaryStructure, i : ResidueId, j : ResidueId)
      @ss_elements << SecondaryStructureElement.new type, i, j
    end

    private def alt_loc(residue : Residue, id : Char, resname : String) : AlternateLocation
      alt_loc = alt_locs[residue].find &.id.==(id)
      alt_locs[residue] << (alt_loc = AlternateLocation.new id, resname) unless alt_loc
      alt_loc
    end

    private def alt_locs : Hash(Residue, Array(AlternateLocation))
      @alt_locs ||= Hash(Residue, Array(AlternateLocation)).new do |hash, key|
        hash[key] = Array(AlternateLocation).new 4
      end
    end

    private def assign_bonds(builder : Structure::Builder) : Nil
      builder.bonds @pdb_bonds unless @pdb_bonds.empty?
    end

    private def assign_secondary_structure(builder : Structure::Builder) : Nil
      @ss_elements.each do |ele|
        builder.secondary_structure ele.start, ele.end, ele.type
      end
    end

    private def current_record : String
      read(0, 6).rstrip.downcase
    end

    private def parse_atom(builder : Structure::Builder) : Nil
      return if @alt_loc && (alt_loc = read?(16)) && alt_loc != @alt_loc

      chid = read(21)
      case chains = @chains
      when Set     then return unless chid.in?(chains)
      when "first" then return if chid != (builder.current_chain.try(&.id) || chid)
      else              nil
      end

      builder.chain chid if chid.alphanumeric?
      builder.residue read(17, 4).strip, read_serial(22, 4), read?(26)
      atom = builder.atom \
        read(12, 4).strip,
        read_serial(6, 5),
        read_vector,
        element: read_element,
        formal_charge: read?(78, 2).try(&.reverse.to_i?) || 0,
        occupancy: read_float(54, 6),
        temperature_factor: read_float(60, 6)

      if !@alt_loc && (alt_loc = read?(16))
        alt_loc(atom.residue, alt_loc, read(17, 4).strip) << atom
      end
    end

    private def parse_bonds : Nil
      i = read_serial 6, 5
      (11..).step(5).each do |start|
        if j = read_serial?(start, 5)
          @pdb_bonds[{i, j}] += 1 unless i > j # skip redundant bonds
        else
          break
        end
      end
    end

    private def parse_expt : Nil
      title = ""
      method = Structure::Experiment::Method::XRayDiffraction
      date = doi = pdbid = resolution = nil

      each_record do |name|
        case name
        when "atom", "hetatm", "cryst1", "model", "seqres", "helix", "sheet"
          back_to_beginning_of_line
          break
        when "expdta"
          raw_method = read(10, 70).split(';')[0].delete "- "
          method = Structure::Experiment::Method.parse raw_method
        when "header"
          date = Time.parse_utc read(50, 9), "%d-%^b-%y"
          pdbid = read(62, 4).downcase
        when "jrnl"
          case read(12, 4).strip.downcase
          when "doi" then doi = read(19, 60).strip
          else            nil
          end
        when "remark"
          next if read(10, 70).blank? # skip remark first line
          case read_int(7, 3)
          when 2 then resolution = read_float?(23, 7)
          else        nil
          end
        when "title"
          title += read(10, 70).rstrip.squeeze ' '
        else
          nil
        end
      end

      if date && pdbid
        @pdb_expt = Structure::Experiment.new title, method, resolution, pdbid, date, doi
        @pdb_title = pdbid
      else
        @pdb_title = title
      end
    end

    private def parse_header
      each_record do |name|
        case name
        when "atom", "hetatm", "model"                     then break
        when "cryst1"                                      then parse_lattice
        when "helix"                                       then parse_helix
        when "sheet"                                       then parse_sheet
        when "header", "title", "expdta", "jrnl", "remark" then parse_expt
        when "seqres"                                      then parse_sequence
        else                                                    nil
        end
      end
    end

    private def parse_helix : Nil
      kind = case read_int(38, 2)
             when 1 then Protein::SecondaryStructure::HelixAlpha
             when 3 then Protein::SecondaryStructure::HelixPi
             when 5 then Protein::SecondaryStructure::Helix3_10
             else        Protein::SecondaryStructure::None
             end
      add_sec kind,
        {read(19), read_int(21, 4), read?(25)},
        {read(19), read_int(33, 4), read?(37)}
    end

    private def parse_lattice
      size = Spatial::Size.new read_float(6, 9), read_float(15, 9), read_float(24, 9)
      @pdb_lattice = Lattice.new \
        size,
        alpha: read_float(33, 7),
        beta: read_float(40, 7),
        gamma: read_float(47, 7)
    end

    private def parse_model : Structure
      @serial = 0
      Structure.build(@guess_topology) do |builder|
        title @pdb_title
        lattice @pdb_lattice
        expt @pdb_expt
        seq @pdb_seq

        each_record do |name|
          case name
          when "atom"          then parse_atom builder
          when "hetatm"        then parse_atom builder if read_het?
          when "conect"        then parse_bonds if @seek_bonds
          when "model"         then seek_bonds if @seek_bonds; break
          when "master", "end" then break
          else                      nil
          end
        end

        resolve_alternate_locations unless @alt_loc
        assign_bonds builder
        assign_secondary_structure builder
      end
    end

    private def parse_sequence : Nil
      @pdb_seq = Protein::Sequence.build do |aminoacids|
        each_record_of("seqres") do
          next if (chains = @chains) && !read(11).in?(chains)
          read(19, 60).split.each { |name| aminoacids << Protein::AminoAcid[name] }
        end
      end
    end

    private def parse_sheet : Nil
      add_sec :beta_strand,
        {read(21), read_int(22, 4), read?(26)},
        {read(21), read_int(33, 4), read?(37)}
    end

    private def read_element : Element?
      case symbol = read?(76, 2).try(&.lstrip)
      when "D" # deuterium
        PeriodicTable::D
      when "X" # unknown, e.g., ASX
        PeriodicTable::X
      when String
        PeriodicTable[symbol]? || parse_exception "Unknown element"
      else
        nil
      end
    end

    private def read_het? : Bool
      @het
    end

    private def read_serial(start : Int, count : Int) : Int32
      Hybrid36.decode read(start, count), count
    end

    private def read_serial?(start : Int, count : Int) : Int32?
      if str = read?(start, count)
        Hybrid36.decode str, count
      end
    end

    private def read_vector : Spatial::Vector
      Spatial::Vector.new read_float(30, 8), read_float(38, 8), read_float(46, 8)
    end

    private def resolve_alternate_locations : Nil
      return unless table = @alt_locs
      table.each do |residue, alt_locs|
        alt_locs.sort! { |a, b| b.occupancy <=> a.occupancy }
        alt_locs.each(within: 1..) do |alt_loc|
          alt_loc.each_atom do |atom|
            residue.delete atom
          end
        end
        residue.name = alt_locs[0].resname
        residue.reset_cache
      end
      table.clear
    end

    private def seek_bonds
      read_context do
        @io.seek 0, ::IO::Seek::End
        each_record_reversed do |name|
          case name
          when "conect"
            parse_bonds
          when "atom", "hetatm", "endmdl", "ter"
            break
          else
            nil
          end
        end
      end
      @seek_bonds = false
    end

    private alias ResidueId = Tuple(Char, Int32, Char?)

    private struct AlternateLocation
      getter id : Char
      getter resname : String

      def initialize(@id : Char, @resname : String)
        @atoms = [] of Atom
      end

      def <<(atom : Atom) : self
        @atoms << atom
        self
      end

      def each_atom(&block : Atom ->) : Nil
        @atoms.each do |atom|
          yield atom
        end
      end

      def occupancy : Float64
        @atoms.sum(&.occupancy) / @atoms.size
      end
    end

    private record SecondaryStructureElement,
      type : Protein::SecondaryStructure,
      start : ResidueId,
      end : ResidueId
  end
end
