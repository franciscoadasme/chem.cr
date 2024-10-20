@[Chem::RegisterFormat(ext: %w(.ent .pdb))]
module Chem::PDB
  class Reader
    include FormatReader(Structure)
    include FormatReader::MultiEntry(Structure)
    include FormatReader::Headed(Structure::Experiment)

    private alias ResidueId = Tuple(Char, Int32, Char?)
    private alias Sec = Protein::SecondaryStructure

    HELIX_TYPES = {
      1 => Sec::RightHandedHelixAlpha,
      3 => Sec::RightHandedHelixPi,
      5 => Sec::RightHandedHelix3_10,
    }

    @pdb_bonds = Hash(Tuple(Int32, Int32), BondOrder).new BondOrder::Zero
    @pdb_cell : Spatial::Parallelepiped?
    @pdb_title = ""
    @header_decoded = false

    @alt_locs : Hash(Residue, Array(AlternateLocation))?
    @builder = uninitialized Structure::Builder
    @chains : Set(Char) | String | Nil
    @seek_bonds = true
    @sec = [] of Tuple(Protein::SecondaryStructure, ResidueId, ResidueId)

    def initialize(@io : IO,
                   @alt_loc : Char? = nil,
                   chains : Enumerable(Char) | String | Nil = nil,
                   @guess_bonds : Bool = false,
                   @het : Bool = true,
                   @sync_close : Bool = false)
      @pull = PullParser.new(@io)
      @chains = chains.is_a?(Enumerable) ? chains.to_set : chains
    end

    def next_entry : Structure?
      decode_header unless @header_decoded
      @pull.each_line do
        case @pull.at(0, 6).str
        when "ATOM  ", "HETATM", "MODEL "
          obj = decode_entry
          @read = true
          return obj
        when "END   ", "MASTER"
          break
        end
      end
    end

    def skip_entry : Nil
      decode_header unless @header_decoded
      @pull.consume_line if @pull.at(0, 6).str == "MODEL "
      @pull.each_line do
        case @pull.at(0, 6).str
        when "ENDMDL"
          @pull.consume_line
          break
        when "MODEL ", "END   ", "MASTER"
          break
        end
      end
    end

    def read_header : Structure::Experiment
      decode_header unless @header_decoded
      @header || @pull.error("Empty header")
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

    private def assign_bonds : Nil
      @builder.bonds @pdb_bonds unless @pdb_bonds.empty?
    end

    private def assign_secondary_structure : Nil
      @sec.each do |(sec, ri, rj)|
        @builder.secondary_structure ri, rj, sec
      end
    end

    private def decode_header : Structure::Experiment
      date = doi = pdbid = resolution = nil
      method = Structure::Experiment::Method::XRayDiffraction
      title = ""

      @pull.each_line do
        case @pull.at?(0, 6).str?
        when "CRYST1"
          x = @pull.at(6, 9).float
          @pull.error "Negative cell size a" if x < 0
          y = @pull.at(15, 9).float
          @pull.error "Negative cell size b" if y < 0
          z = @pull.at(24, 9).float
          @pull.error "Negative cell size c" if z < 0
          alpha = @pull.at(33, 7).float
          @pull.error "Invalid cell angle alpha" unless 0 < alpha <= 180
          beta = @pull.at(40, 7).float
          @pull.error "Invalid cell angle beta" unless 0 < beta <= 180
          gamma = @pull.at(47, 7).float
          @pull.error "Invalid cell angle gamma" unless 0 < gamma <= 180

          case {x, y, z, alpha, beta, gamma}
          when {0, 0, 0, 90, 90, 90}, {1, 1, 1, 90, 90, 90}
            next
          when {.positive?, .positive?, .positive?, .positive?, .positive?, .positive?}
            @pdb_cell = Spatial::Parallelepiped.new({x, y, z}, {alpha, beta, gamma})
          else
            @pull.error "Invalid cell parameters: #{{x, y, z, alpha, beta, gamma}}"
          end
        when "EXPDTA"
          str = @pull.at(10, 70).str.split(';')[0].delete "- "
          method = Structure::Experiment::Method.parse str
        when "HEADER"
          date = @pull.at?(50, 9).str?.presence.try do |str|
            Time.parse_utc str, "%d-%^b-%y"
          end
          pdbid = @pull.at?(62, 4).str?.presence
        when "HELIX "
          sec = HELIX_TYPES[@pull.at(38, 2).int]? || @pull.error("Invalid helix type")
          ch1 = @pull.at(19).char.presence || @pull.error("Blank chain id")
          ch2 = @pull.at(31).char.presence || @pull.error("Blank chain id")
          @pull.error("Different chain ids in HELIX record") if ch1 != ch2
          num1 = seqnum_at(21, 4)
          inscode1 = @pull.at(25).char.presence
          num2 = seqnum_at(33, 4)
          inscode2 = @pull.at(37).char.presence
          @sec << {sec, {ch1, num1, inscode1}, {ch2, num2, inscode2}}
        when "JRNL  "
          case @pull.at(12, 4).str
          when "DOI " then doi = @pull.at(19, 60).str.strip
          end
        when "REMARK"
          case @pull.at?(7, 3).str?
          when "  2"
            resolution = @pull.at?(23, 7).float?
          end
        when "SHEET "
          ch1 = @pull.at(21).char.presence || @pull.error("Blank chain id")
          ch2 = @pull.at(32).char.presence || @pull.error("Blank chain id")
          @pull.error("Different chain ids in SHEET record") if ch1 != ch2
          num1 = seqnum_at(22, 4)
          inscode1 = @pull.at(26).char.presence
          num2 = seqnum_at(33, 4)
          inscode2 = @pull.at(37).char.presence
          @sec << {Sec::BetaStrand, {ch1, num1, inscode1}, {ch2, num2, inscode2}}
        when "TITLE "
          title += @pull.at(10, 70).str.rstrip.squeeze(' ')
        when "ATOM  ", "HETATM", "MODEL "
          break
        end
      end

      if date && pdbid
        @header = Structure::Experiment.new title, method, resolution, pdbid, date, doi
        @pdb_title = pdbid
      else
        @pdb_title = title
      end

      @header_decoded = true
      @header || Structure::Experiment.new "", method, nil, "", Time::UNIX_EPOCH, nil
    end

    private def read_atom : Nil
      alt_loc = @pull.at(16).char.presence
      occupancy = @pull.at?(54, 6).float(if_blank: 0)
      return if @alt_loc && alt_loc && alt_loc != @alt_loc && occupancy < 1

      chid = @pull.at(21).char
      case chains = @chains
      when Set     then return unless chid.in?(chains)
      when "first" then return if chid != (@builder.current_chain.try(&.id) || chid)
      end

      atom_name = @pull.at(12, 4).str.strip
      ele = case symbol = @pull.at?(76, 2).str?.presence.try(&.strip)
            when "D"
              PeriodicTable::H # deuterium
            when String
              PeriodicTable[symbol]? || @pull.error("Unknown element")
            else
              Structure.guess_element?(atom_name) || @pull.error("Could not guess element")
            end

      @builder.chain chid if chid.alphanumeric?
      resnum = seqnum_at(22, 4)
      inscode = @pull.at(26).char.presence
      resname = @pull.at(17, 4).str.strip
      residue = @builder.residue resname, resnum, inscode

      if alt_loc.nil? && resname != residue.name
        @pull.error "Found different name #{resname.inspect} for #{residue}"
      end

      x = @pull.at(30, 8).float
      y = @pull.at(38, 8).float
      z = @pull.at(46, 8).float
      formal_charge = @pull.at?(78, 2).str?.presence.try do |str|
        str.reverse.to_i? || @pull.error("Invalid formal charge")
      end
      atom = @builder.atom \
        atom_name,
        seqnum_at(6, 5),
        Spatial::Vec3.new(x, y, z),
        element: ele,
        formal_charge: formal_charge || 0,
        occupancy: occupancy,
        temperature_factor: @pull.at?(60, 6).float(if_blank: 0)

      alt_loc(atom.residue, alt_loc, resname) << atom if !@alt_loc && alt_loc
    end

    private def read_bonds : Nil
      i = seqnum_at(6, 5)
      (11..).step(5).each do |start|
        break unless j = seqnum_at?(start, 5)
        @pdb_bonds.update({i, j}, &.succ) unless i > j # skip redundant bonds
      end
    end

    private def read_het? : Bool
      @het
    end

    private def decode_entry : Structure
      @pull.consume_line if @pull.at(0, 6).str == "MODEL "

      @builder = Structure::Builder.new(
        guess_bonds: @guess_bonds,
        guess_names: false,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
        use_templates: true,
      )
      @builder.title @pdb_title
      @builder.cell @pdb_cell
      @builder.expt @header

      @pdb_bonds.clear
      @number = 0
      @pull.each_line do
        case @pull.at?(0, 6).str?
        when "ATOM  "
          read_atom
        when "HETATM"
          read_atom if read_het?
        when "CONECT"
          read_bonds
        when "ENDMDL"
          @pull.consume_line
          break
        when "END", "END   ", "MODEL ", "MASTER"
          break
        end
      end

      resolve_alternate_locations unless @alt_loc
      assign_bonds
      assign_secondary_structure

      @builder.build
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

    private def seqnum_at(start : Int, size : Int) : Int32
      seqnum_at?(start, size) || @pull.error("Invalid sequence number")
    end

    private def seqnum_at?(start : Int, size : Int) : Int32?
      @pull.at?(start, size).parse? { |str| Hybrid36.decode?(str) }
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

  class Writer
    include FormatWriter(AtomContainer)
    include FormatWriter::MultiEntry(AtomContainer)

    LINE_WIDTH       = 80
    PDB_VERSION      = "3.30"
    PDB_VERSION_DATE = Time.local 2011, 7, 13
    WHITESPACE       = ' '

    # Controls which bonds are written to a PDB.
    @[Flags]
    enum BondOptions
      # Write CONECT records for standard residues (including water)
      Standard
      # Write CONECT records for disulfide bridges
      Disulfide
      # Write CONECT records for non-standard (HET) groups excluding
      # water (both intra- and inter-residue bonds)
      Het
    end

    @atom_index_table = {} of Int32 => Int32
    @record_index = 0

    def initialize(
      @io : IO,
      # FIXME: add scope to type when creating constructors in register_format
      @bonds : Chem::PDB::Writer::BondOptions = Chem::PDB::Writer::BondOptions.flags(Het, Disulfide),
      @renumber : Bool = true,
      @ter_on_fragment : Bool = false,
      @total_entries : Int32? = nil,
      @sync_close : Bool = false
    )
      check_total_entries
    end

    def close : Nil
      @io.printf "%-#{LINE_WIDTH}s\n", "END"
      super
    end

    protected def encode_entry(obj : AtomContainer) : Nil
      @record_index = 0

      if @entry_index == 0
        obj.is_a?(Structure) ? write_header(obj) : write_pdb_version
        formatl "NUMMDL    %-4d%66s", @total_entries, ' ' if multi? && @total_entries
      end

      formatl "MODEL     %4d%66s", @entry_index + 1, ' ' if multi?
      if obj.is_a?(Structure)
        if (cell = obj.cell?) &&
           !(cell.basisvec[0].parallel?(:x) && cell.basisvec[1].z.zero?)
          # compute the unit cell aligned to the xy-plane
          ref = Spatial::Parallelepiped.new cell.size, cell.angles
          transform = Spatial::Transform
            .aligning(cell.basisvec[..1], to: ref.basisvec[..1])
            .translate(cell.origin)
          Log.warn do
            "Aligning unit cell to the XY plane for writing PDB. \
             This will change the atom coordinates."
          end
        end

        obj.chains.each do |chain|
          p_res = nil
          chain.residues.each do |residue|
            # assume residues are ordered by connectivity, so a chain
            # break (new fragment) can be detected if residue i and i+1
            # are not bonded
            write_ter p_res if @ter_on_fragment && p_res && !p_res.bonded?(residue)
            residue.atoms.each { |atom| write atom, transform }
            p_res = residue
          end
          # assume that a chain is one or multiple (chain breaks) fragments
          write_ter p_res if p_res && (p_res.polymer? || @ter_on_fragment)
        end
      elsif @ter_on_fragment
        atoms = obj.is_a?(AtomView) ? obj : obj.atoms
        atoms.each_fragment do |atoms|
          atoms.each do |atom|
            write atom
          end
          write_ter atoms[-1].residue
        end
      else
        atoms = obj.is_a?(AtomView) ? obj : obj.atoms
        atoms.each { |atom| write atom }
      end

      unless @bonds.none?
        bonds = obj.responds_to?(:bonds) ? obj.bonds : obj.atoms.bonds
        if @bonds != BondOptions::All
          bonds.select! do |bond|
            a, b = bond.atoms
            ok = false
            ok ||= (a.protein? || a.water?) && (b.protein? || b.water?) if @bonds.standard?
            ok ||= (a.het? && !a.water?) || (b.het? && !b.water?) if @bonds.het?
            ok ||= a.sulfur? && b.sulfur? && a.residue != b.residue if @bonds.disulfide?
            ok
          end
        end
        write_bonds bonds
      end

      formatl "%-#{LINE_WIDTH}s", "ENDMDL" if multi?
    end

    private def index(atom : Atom) : Int32
      idx = next_index
      @atom_index_table[atom.number] = idx if @bonds
      idx
    end

    private def next_index : Int32
      @record_index += 1
    end

    private def write(atom : Atom, transform : Spatial::Transform? = nil) : Nil
      vec = atom.pos
      vec = transform * vec if transform
      @io.printf "%-6s%5s %4s %-4s%s%4s%1s   %8.3f%8.3f%8.3f%6.2f%6.2f          %2s%2s\n",
        (atom.residue.protein? ? "ATOM" : "HETATM"),
        PDB::Hybrid36.encode(@renumber ? index(atom) : atom.number, width: 5),
        atom.name[..3].ljust(3),
        atom.residue.name[..3],
        atom.chain.id,
        PDB::Hybrid36.encode(atom.residue.number, width: 4),
        atom.residue.insertion_code,
        vec.x,
        vec.y,
        vec.z,
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

    private def write(cell : Spatial::Parallelepiped) : Nil
      a, b, c = cell.size
      alpha, beta, gamma = cell.angles
      @io.printf "CRYST1%9.3f%9.3f%9.3f%7.2f%7.2f%7.2f %-11s%4d          \n",
        a,
        b,
        c,
        alpha,
        beta,
        gamma,
        "P 1", # default space group
        1      # default Z value
    end

    private def write_bonds(bonds : Array(Bond)) : Nil
      idx_pairs = Array(Tuple(Int32, Int32)).new bonds.size
      bonds.each do |bond|
        i, j = bond.atoms.map(&.number)
        i, j = @atom_index_table[i], @atom_index_table[j] if @renumber
        bond.order.to_i.times do
          idx_pairs << {i, j} << {j, i}
        end
      end

      idx_pairs.sort!.chunk(&.[0]).each do |i, pairs|
        pairs.each_slice(4, reuse: true) do |slice|
          @io << "CONECT"
          Hybrid36.encode @io, i, width: 5
          slice.each { |pair| Hybrid36.encode @io, pair[1], width: 5 }
          @io.puts " " * (LINE_WIDTH - 6 - 5 - slice.size * 5)
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
      structure.cell?.try { |cell| write cell }
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
      structure.residues.secondary_structures
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

    def encode(io : IO, num : Int, width : Int) : Nil
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
end
