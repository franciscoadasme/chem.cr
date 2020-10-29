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
      return (num + 10*36**(width - 1)).to_s io, base: 36, upcase: true if num < 26*36**(width - 1)
      num -= 26*36**(width - 1)
      return (num + 10*36**(width - 1)).to_s io, base: 36 if num < 26*36**(width - 1)
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
      write_sec structure
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

    private def write_sec(structure : Structure) : Nil
      helix_id = sheet_id = 0
      structure.secondary_structures
        .select!(&.[0].sec.regular?)
        .sort_by! do |residues|
          {residues[0].sec.beta_strand? ? 1 : -1, residues[0]}
        end
        .each do |residues|
          case residues[0].sec
          when .beta_strand?
            write_sheet (sheet_id += 1), residues
          when .left_handed_helix3_10?
            write_helix (helix_id += 1), residues, helix_type: 11
          when .left_handed_helix_alpha?
            write_helix (helix_id += 1), residues, helix_type: 6
          when .left_handed_helix_gamma?
            write_helix (helix_id += 1), residues, helix_type: 8
          when .left_handed_helix_pi?
            write_helix (helix_id += 1), residues, helix_type: 13
          when .polyproline?
            write_helix (helix_id += 1), residues, helix_type: 10
          when .right_handed_helix3_10?
            write_helix (helix_id += 1), residues, helix_type: 5
          when .right_handed_helix_alpha?
            write_helix (helix_id += 1), residues, helix_type: 1
          when .right_handed_helix_gamma?
            write_helix (helix_id += 1), residues, helix_type: 4
          when .right_handed_helix_pi?
            write_helix (helix_id += 1), residues, helix_type: 3
          end
        end
    end

    private def write_helix(id : Int, residues : ResidueView, helix_type : Int) : Nil
      @io.printf "%-6s %3d %3d %3s %s %4d%1s %3s %s %4d%1s%2d%30s%6d    \n",
        "HELIX",
        id,
        id,
        residues[0].name,
        residues[0].chain.id,
        residues[0].number,
        residues[0].insertion_code,
        residues[-1].name,
        residues[-1].chain.id,
        residues[-1].number,
        residues[-1].insertion_code,
        helix_type,
        "",
        residues.size
    end

    private def write_sheet(id : Int, residues : ResidueView) : Nil
      @io.printf "%-6s %3d %3s%2s %3s %1s%4d%1s %3s %1s%4d%1s%2s%40s\n",
        "SHEET",
        id,  # strand number
        nil, # sheet identifier
        nil, # number of strands in sheet
        residues[0].name,
        residues[0].chain.id,
        residues[0].number,
        residues[0].insertion_code,
        residues[-1].name,
        residues[-1].chain.id,
        residues[-1].number,
        residues[-1].insertion_code,
        nil, # strand sense (first strand = 0, parallel = 1, anti-parallel = -1)
        ""
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
  class Reader < Structure::Reader
    private alias ResidueId = Tuple(Char, Int32, Char?)

    @pdb_bonds = Hash(Tuple(Int32, Int32), Int32).new 0
    @pdb_expt : Structure::Experiment?
    @pdb_lattice : Lattice?
    @pdb_seq : Protein::Sequence?
    @pdb_title = ""

    @alt_locs : Hash(Residue, Array(AlternateLocation))?
    @chains : Set(Char) | String | Nil
    @seek_bonds = true
    @ss_elements = [] of Tuple(Protein::SecondaryStructure, ResidueId, ResidueId)

    def initialize(input : ::IO,
                   @alt_loc : Char? = nil,
                   chains : Enumerable(Char) | String | Nil = nil,
                   guess_topology : Bool = true,
                   @het : Bool = true,
                   sync_close : Bool = true)
      super input, guess_topology, sync_close: sync_close
      @chains = chains.is_a?(Enumerable) ? chains.to_set : chains
      parse_header
    end

    def self.new(path : Path | String, **options) : self
      new ::IO::Memory.new(File.read(path)), **options, sync_close: true
    end

    def next : Structure | Iterator::Stop
      until @parser.eof?
        case @parser.skip_whitespace
        when .check("ATOM", "HETATM", "MODEL")
          return parse_model
        when .check("END", "MASTER")
          break
        else
          @parser.skip_line
        end
      end
      stop
    end

    def skip_structure : Nil
      @parser.skip_line if @parser.skip_whitespace.check("MODEL")
      until @parser.eof?
        case @parser.skip_whitespace
        when .check("ENDMDL")
          @parser.skip_line
          break
        when .check("MODEL", "CONECT", "END", "MASTER")
          break
        else
          @parser.skip_line
        end
      end
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
        builder.secondary_structure ele[1], ele[2], ele[0]
      end
    end

    private def parse_atom(builder : Structure::Builder) : Nil
      line = @parser.read_line

      alt_loc = line[16].presence
      return if @alt_loc && alt_loc && alt_loc != @alt_loc

      chid = line[21]
      case chains = @chains
      when Set     then return unless chid.in?(chains)
      when "first" then return if chid != (builder.current_chain.try(&.id) || chid)
      end

      ele = case symbol = line[76, 2]?.presence.try(&.strip)
            when "D" # deuterium
              PeriodicTable::D
            when "X" # unknown, e.g., ASX
              PeriodicTable::X
            when String
              PeriodicTable[symbol]
            end

      builder.chain chid if chid.alphanumeric?
      resname = line[17, 4].strip
      builder.residue resname, Hybrid36.decode(line[22, 4]), line[26].presence
      atom = builder.atom \
        line[12, 4].strip,
        Hybrid36.decode(line[6, 5]),
        Spatial::Vector.new(line[30, 8].to_f, line[38, 8].to_f, line[46, 8].to_f),
        element: ele,
        formal_charge: line[78, 2]?.try(&.reverse.to_i?) || 0,
        occupancy: line[54, 6].to_f,
        temperature_factor: line[60, 6].to_f

      alt_loc(atom.residue, alt_loc, resname) << atom if !@alt_loc && alt_loc
    end

    private def parse_bonds : Nil
      line = @parser.read_line
      i = Hybrid36.decode line[6, 5]
      (11..).step(5).each do |start|
        if (str = line[start, 5]?.presence) && (j = Hybrid36.decode(str))
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

      until @parser.eof?
        case @parser.skip_whitespace
        when .check("ATOM", "HETATM", "CRYST1", "MODEL", "SEQRES", "HELIX", "SHEET")
          break
        when .check("EXPDTA")
          str = @parser.read_line[10, 70].split(';')[0].delete "- "
          method = Structure::Experiment::Method.parse str
        when .check("HEADER")
          line = @parser.read_line
          date = line[50, 9]?.try { |str| Time.parse_utc str, "%d-%^b-%y" }
          pdbid = line[62, 4]?
        when .check("JRNL")
          line = @parser.read_line
          case line[12, 4].strip
          when "DOI" then doi = line[19, 60].strip
          end
        when .check("REMARK")
          line = @parser.read_line
          next if line[10, 70].blank? # skip remark first line
          case line[7, 3].presence.try(&.lstrip)
          when "2"
            resolution = line[23, 7].to_f?
          when nil
            pdbid = line[11, 4].presence
            date = Time.local
          end
        when .check("TITLE")
          title += @parser.read_line[10, 70].rstrip.squeeze ' '
        else
          @parser.skip_line
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
      until @parser.eof?
        case @parser.skip_whitespace
        when .check("ATOM", "HETATM", "MODEL")                     then break
        when .check("CRYST1")                                      then parse_lattice
        when .check("HELIX")                                       then parse_helix
        when .check("SHEET")                                       then parse_sheet
        when .check("HEADER", "TITLE", "EXPDTA", "JRNL", "REMARK") then parse_expt
        when .check("SEQRES")                                      then parse_sequence
        else                                                            @parser.skip_line
        end
      end
    end

    # FIXME: add additional cases (including non-standard codes)
    private def parse_helix : Nil
      line = @parser.read_line
      sec = case line[38, 2].to_i
            when 1 then Protein::SecondaryStructure::RightHandedHelixAlpha
            when 3 then Protein::SecondaryStructure::RightHandedHelixPi
            when 5 then Protein::SecondaryStructure::RightHandedHelix3_10
            else        Protein::SecondaryStructure::None
            end
      @ss_elements << {
        sec,
        {line[19], line[21, 4].to_i, line[25].presence},
        {line[19], line[33, 4].to_i, line[37].presence},
      }
    end

    private def parse_lattice
      line = @parser.read_line
      size = Spatial::Size.new line[6, 9].to_f, line[15, 9].to_f, line[24, 9].to_f
      @pdb_lattice = Lattice.new size, line[33, 7].to_f, line[40, 7].to_f, line[47, 7].to_f
    end

    private def parse_model : Structure
      @parser.skip_line if @parser.check("MODEL")
      @serial = 0
      Structure.build(@guess_topology) do |builder|
        title @pdb_title
        lattice @pdb_lattice
        expt @pdb_expt
        seq @pdb_seq

        until @parser.eof?
          case @parser.skip_whitespace
          when .check("ATOM")
            parse_atom builder
          when .check("HETATM")
            read_het? ? parse_atom(builder) : @parser.skip_line
          when .check("CONECT")
            @seek_bonds ? parse_bonds : @parser.skip_line
          when .check("MODEL") # another model
            # seek_bonds if @seek_bonds
            @parser.skip_line
            break
          when .check("MASTER", "END")
            @parser.skip_line
            break
          else
            @parser.skip_line
          end
        end

        resolve_alternate_locations unless @alt_loc
        assign_bonds builder
        assign_secondary_structure builder
      end
    end

    private def parse_sequence : Nil
      @pdb_seq = Protein::Sequence.build do |aminoacids|
        until @parser.eof?
          case @parser.skip_whitespace
          when .check("SEQRES")
            line = @parser.read_line
            next if (chains = @chains) && !line[11].in?(chains)
            line[19, 60].split.each do |resname|
              aminoacids << Protein::AminoAcid[resname]
            end
          else
            break
          end
        end
      end
    end

    private def parse_sheet : Nil
      line = @parser.read_line
      @ss_elements << {
        Protein::SecondaryStructure::BetaStrand,
        {line[21], line[22, 4].to_i, line[26].presence},
        {line[21], line[33, 4].to_i, line[37].presence},
      }
    end

    private def read_het? : Bool
      @het
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
  end
end
