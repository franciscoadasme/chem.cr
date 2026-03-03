@[Chem::RegisterFormat(ext: %w(.ent .pdb))]
module Chem::PDB
  # Controls which CONECT records are written to a PDB.
  @[Flags]
  enum ConectOptions
    # Write CONECT records for standard residues (including water)
    Standard
    # Write CONECT records for disulfide bridges
    Disulfide
    # Write CONECT records for non-standard (HET) groups excluding
    # water (both intra- and inter-residue bonds)
    Het
  end

  # A secondary structure record (HELIX or SHEET) in the PDB.
  struct SecondaryStructureRecord
    # Identifier for the first residue of the secondary structure element.
    getter begin : ResidueId
    # Identifier for the last residue of the secondary structure element.
    getter end : ResidueId
    # Secondary structure.
    getter type : Protein::SecondaryStructure

    protected def initialize(@type, @begin, @end); end
  end

  # Experimental and structural information from the PDB header.
  # Use `.read_info` to get it.
  struct Info
    # Unit cell of the structure if present in the header, else `nil`.
    getter cell : Spatial::Parallelepiped?
    # Experimental information of the structure if present in the header, else `nil`.
    getter experiment : Structure::Experiment?
    # Title of the structure.
    getter title : String
    # List of secondary structure (HELIX and SHEET) records.
    getter sec_records : Array(SecondaryStructureRecord)

    protected def initialize(@cell, @experiment, @title, @sec_records); end
  end

  # Yields each structure in *io*.
  #
  # If passed, only chains in *chains* will be read, otherwise all chains will be read.
  # Similarly, HET atoms can be excluded by setting *het* to *false*.
  #
  # If the structure has alternate locations, only the most populated one will be read unless *alt_loc* is set.
  def self.each(
    io : IO,
    alt_loc : Char? = nil,
    chains : Enumerable(Char) | String | Nil = nil,
    guess_bonds : Bool = false,
    het : Bool = true,
    & : Structure ->
  ) : Nil
    info = read_info(io)
    loop do
      yield read(io, info, alt_loc: alt_loc, chains: chains, guess_bonds: guess_bonds, het: het)
    rescue IO::EOFError
      break
    end
  end

  # :ditto:
  def self.each(
    path : Path | String,
    alt_loc : Char? = nil,
    chains : Enumerable(Char) | String | Nil = nil,
    guess_bonds : Bool = false,
    het : Bool = true,
    & : Structure ->
  ) : Nil
    File.open(path) do |file|
      each(file, alt_loc: alt_loc, chains: chains, guess_bonds: guess_bonds, het: het) do |struc|
        yield struc
      end
    end
  end

  # Returns the next structure from *io*.
  # Raises `IO::EOFError` when there are no more structures.
  # Use `.read_all` or `.each` for multiple.
  #
  # Experimental and structural data specified in the header is set from *info*.
  # If *info* is nil and *io* is at the beginning, the header is read first.
  #
  # If passed, only chains in *chains* will be read, otherwise all chains will be read.
  # Similarly, HET atoms can be excluded by setting *het* to *false*.
  #
  # If the structure has alternate locations, only the most populated one will be read unless *alt_loc* is set.
  def self.read(
    io : IO,
    info : Info? = nil,
    alt_loc : Char? = nil,
    chains : Enumerable(Char) | String | Nil = nil,
    guess_bonds : Bool = false,
    het : Bool = true,
  ) : Structure
    info ||= read_info(io)
    pull = PullParser.new(io)
    pull.each_line do
      case pull.at(0, 6).str
      when "ATOM  ", "HETATM", "MODEL "
        pull.consume_line if pull.at(0, 6).str == "MODEL "

        builder = Structure::Builder.new(
          guess_bonds: guess_bonds,
          guess_names: false,
          source_file: (file = io).is_a?(File) ? file.path : nil,
          use_templates: true,
        )
        builder.title info.title
        builder.cell info.cell
        builder.expt info.experiment

        pdb_bonds = Hash(Tuple(Int32, Int32), BondOrder).new BondOrder::Zero
        alt_locs = Hash(Residue, Array(AlternateLocation)).new do |hash, key|
          hash[key] = Array(AlternateLocation).new 4
        end
        chains_set = chains.is_a?(Enumerable) ? chains.to_set : chains

        pull.each_line do
          case pull.at?(0, 6).str?
          when "ATOM  ", "HETATM"
            next if pull.at(0, 6).str == "HETATM" && !het

            alt_loc_char = pull.at(16).char.presence
            occupancy = pull.at?(54, 6).float(if_blank: 0)
            next if alt_loc && alt_loc_char && alt_loc_char != alt_loc && occupancy < 1

            chid = pull.at(21).char
            case chains_set
            when Set     then next unless chid.in?(chains_set)
            when "first" then next if chid != (builder.current_chain.try(&.id) || chid)
            end

            atom_name = pull.at(12, 4).str.strip
            ele = case symbol = pull.at?(76, 2).str?.presence.try(&.strip)
                  when "D"
                    PeriodicTable::H
                  when String
                    PeriodicTable[symbol]? || pull.error("Unknown element")
                  else
                    Structure.guess_element?(atom_name) || pull.error("Could not guess element")
                  end

            builder.chain chid if chid.alphanumeric?
            resnum = read_serial(pull, 22, 4)
            inscode = pull.at(26).char.presence
            resname = pull.at(17, 4).str.strip
            residue = builder.residue resname, resnum, inscode

            pull.error "Found different name #{resname.inspect} for #{residue}" if alt_loc_char.nil? && resname != residue.name

            x = pull.at(30, 8).float
            y = pull.at(38, 8).float
            z = pull.at(46, 8).float
            formal_charge = pull.at?(78, 2).str?.presence.try { |str| str.reverse.to_i? || pull.error("Invalid formal charge") }
            atom = builder.atom \
              atom_name,
              read_serial(pull, 6, 5),
              Spatial::Vec3.new(x, y, z),
              element: ele,
              formal_charge: formal_charge || 0,
              occupancy: occupancy,
              temperature_factor: pull.at?(60, 6).float(if_blank: 0)

            if !alt_loc && alt_loc_char
              loc = alt_locs[atom.residue].find &.id.==(alt_loc_char)
              alt_locs[atom.residue] << (loc = AlternateLocation.new alt_loc_char, resname) unless loc
              loc << atom
            end
          when "CONECT"
            i = read_serial(pull, 6, 5)
            (11..).step(5).each do |start|
              break unless j = read_serial?(pull, start, 5)
              pdb_bonds.update({i, j}, &.succ) unless i > j
            end
          when "ENDMDL"
            # pull.consume_line
            break
          when "END", "END   ", "MODEL ", "MASTER"
            # FIXME: hack such that the next call to read can start at this line
            if line = pull.line
              io.pos -= line.bytesize + 1
              io.pos += 1 if io.peek[0]?.try(&.unsafe_chr) == '\n'
            end
            break
          end
        end

        if alt_loc.nil?
          # resolve alternate locations
          alt_locs.each do |residue, locs|
            locs.sort! { |a, b| b.occupancy <=> a.occupancy }
            locs.each(within: 1..) do |loc|
              loc.each_atom do |atom|
                residue.delete atom
              end
            end
            residue.name = locs[0].resname
            residue.reset_cache
          end
        end
        builder.bonds pdb_bonds unless pdb_bonds.empty?
        info.sec_records.each do |sec|
          builder.secondary_structure sec.begin, sec.end, sec.type
        end

        return builder.build
      when "END   ", "MASTER"
        break
      end
    end
    raise IO::EOFError.new
  end

  # :ditto:
  #
  # TODO: create macro to create this overload
  def self.read(
    path : Path | String,
    alt_loc : Char? = nil,
    chains : Enumerable(Char) | String | Nil = nil,
    guess_bonds : Bool = false,
    het : Bool = true,
  ) : Structure
    File.open(path) do |file|
      read(file, alt_loc: alt_loc, chains: chains, guess_bonds: guess_bonds, het: het)
    end
  end

  # Returns all structures in *io*.
  #
  # If passed, only chains in *chains* will be read, otherwise all chains will be read.
  # Similarly, HET atoms can be excluded by setting *het* to *false*.
  #
  # If the structure has alternate locations, only the most populated one will be read unless *alt_loc* is set.
  def self.read_all(
    io : IO,
    alt_loc : Char? = nil,
    chains : Enumerable(Char) | String | Nil = nil,
    guess_bonds : Bool = false,
    het : Bool = true,
  ) : Array(Structure)
    ary = [] of Structure
    each(io, alt_loc: alt_loc, chains: chains, guess_bonds: guess_bonds, het: het) { |s| ary << s }
    ary
  end

  # :ditto:
  #
  # TODO: create macro to create this overload
  def self.read_all(
    path : Path | String,
    alt_loc : Char? = nil,
    chains : Enumerable(Char) | String | Nil = nil,
    guess_bonds : Bool = false,
    het : Bool = true,
  ) : Array(Structure)
    File.open(path) do |file|
      read_all(file, alt_loc: alt_loc, chains: chains, guess_bonds: guess_bonds, het: het)
    end
  end

  # Returns the info from *io*.
  # It must be called at the beginning of the PDB content and before reading structures via `.read`.
  def self.read_info(io : IO) : Info
    cell = nil
    date = doi = pdbid = resolution = nil
    method = Structure::Experiment::Method::XRayDiffraction
    title = ""
    sec_records = [] of SecondaryStructureRecord

    pull = PullParser.new(io)
    pull.each_line do
      case pull.at?(0, 6).str?
      when "CRYST1"
        x = pull.at(6, 9).float
        pull.error "Negative cell size a" if x < 0
        y = pull.at(15, 9).float
        pull.error "Negative cell size b" if y < 0
        z = pull.at(24, 9).float
        pull.error "Negative cell size c" if z < 0
        alpha = pull.at(33, 7).float
        pull.error "Invalid cell angle alpha" unless 0 < alpha <= 180
        beta = pull.at(40, 7).float
        pull.error "Invalid cell angle beta" unless 0 < beta <= 180
        gamma = pull.at(47, 7).float
        pull.error "Invalid cell angle gamma" unless 0 < gamma <= 180

        case {x, y, z, alpha, beta, gamma}
        when {0, 0, 0, 90, 90, 90}, {1, 1, 1, 90, 90, 90}
          next
        when {.positive?, .positive?, .positive?, .positive?, .positive?, .positive?}
          cell = Spatial::Parallelepiped.new({x, y, z}, {alpha, beta, gamma})
        else
          pull.error "Invalid cell parameters: #{{x, y, z, alpha, beta, gamma}}"
        end
      when "EXPDTA"
        str = pull.at(10, 70).str.split(';')[0].delete "- "
        method = Structure::Experiment::Method.parse str
      when "HEADER"
        date = pull.at?(50, 9).str?.presence.try { |str| Time.parse_utc str, "%d-%^b-%y" }
        pdbid = pull.at?(62, 4).str?.presence
      when "HELIX "
        sec_type = case pull.at(38, 2).int
                   when 1 then Protein::SecondaryStructure::RightHandedHelixAlpha
                   when 3 then Protein::SecondaryStructure::RightHandedHelixPi
                   when 5 then Protein::SecondaryStructure::RightHandedHelix3_10
                   else        pull.error("Invalid helix type")
                   end
        ch1 = pull.at(19).char.presence || pull.error("Blank chain id")
        ch2 = pull.at(31).char.presence || pull.error("Blank chain id")
        pull.error("Different chain ids in HELIX record") if ch1 != ch2
        num1 = read_serial(pull, 21, 4)
        inscode1 = pull.at(25).char.presence
        initial_resid = {ch1, num1, inscode1}
        num2 = read_serial(pull, 33, 4)
        inscode2 = pull.at(37).char.presence
        terminal_resid = {ch2, num2, inscode2}
        sec_records << SecondaryStructureRecord.new(sec_type, initial_resid, terminal_resid)
      when "JRNL  "
        case pull.at(12, 4).str
        when "DOI " then doi = pull.at(19, 60).str.strip
        end
      when "REMARK"
        case pull.at?(7, 3).str?
        when "  2"
          resolution = pull.at?(23, 7).float?
        end
      when "SHEET "
        ch1 = pull.at(21).char.presence || pull.error("Blank chain id")
        ch2 = pull.at(32).char.presence || pull.error("Blank chain id")
        pull.error("Different chain ids in SHEET record") if ch1 != ch2
        num1 = read_serial(pull, 22, 4)
        inscode1 = pull.at(26).char.presence
        initial_resid = {ch1, num1, inscode1}
        num2 = read_serial(pull, 33, 4)
        inscode2 = pull.at(37).char.presence
        terminal_resid = {ch2, num2, inscode2}
        sec_records << SecondaryStructureRecord.new(:beta_strand, initial_resid, terminal_resid)
      when "TITLE "
        title += pull.at(10, 70).str.rstrip.squeeze(' ')
      when "ATOM  ", "HETATM", "MODEL "
        # FIXME: hack such that the next call to read can start at this line
        # TODO: add pull.rewind_line to PullParser. Use 1: false, then chomp but save real bytesize
        if line = pull.line
          io.pos -= line.bytesize + 1
          io.pos += 1 if io.peek[0]?.try(&.unsafe_chr) == '\n'
        end
        break
      end
    end

    if date && pdbid
      experiment = Structure::Experiment.new(title, method, resolution, pdbid, date, doi)
      title = pdbid
    end

    Info.new(cell, experiment, title, sec_records)
  end

  # :ditto:
  def self.read_info(path : Path | String) : Info
    File.open(path) do |file|
      read_info(file)
    end
  end

  # Returns the experimental information from the header of *io*.
  #
  # TODO: Remove in favor of `read_info`.
  def self.read_header(io : IO) : Structure::Experiment
    read_info(io).experiment || raise ParseException.new("Empty header")
  end

  # :ditto:
  def self.read_header(path : Path | String) : Structure::Experiment
    File.open(path) do |file|
      read_header(file)
    end
  end

  # Writes one or more structures or groups of atoms to *io*.
  #
  # Atom numbering starts from 1 and increments sequentially if *renumber* is true, otherwise the atom numbers are written as is.
  #
  # CONECT records are written for HET residues and disulfide bridges only, but can be changed using *conect*.
  # TER records are written for each fragment if *ter_on_fragment* is true.
  #
  # If *include_header* is true, the experimental data, secondary structure, unit cell, and other information is written if available.
  # If *include_end* is true, the END record is written at the end of the output.
  def self.write(
    io : IO,
    struc : AtomView | Structure,
    conect conect_options : PDB::ConectOptions = PDB::ConectOptions.flags(Het, Disulfide),
    renumber : Bool = true,
    ter_on_fragment : Bool = false,
    include_header : Bool = true,
    include_end : Bool = true,
  ) : Nil
    write_header(io, struc) if include_header

    atom_index_table = {} of Int32 => Int32
    serial = 0
    if struc.is_a?(Structure)
      transform = nil
      if (cell = struc.cell?) && !(cell.basisvec[0].parallel?(:x) && cell.basisvec[1].z.zero?)
        transform = Spatial::Transform
          .aligning(cell.basisvec[..1], to: {Spatial::Vec3::X, Spatial::Vec3::Y})
          .translate(cell.origin)
        Log.warn do
          "Aligning unit cell to the XY plane for writing PDB. \
           This will change the atom coordinates."
        end
      end

      struc.chains.each do |chain|
        prev_res = nil
        chain.residues.each do |residue|
          write_ter(io, prev_res, (serial += 1 if renumber)) if ter_on_fragment && prev_res && !residue.bonded?(prev_res)
          residue.atoms.each do |atom|
            pos = atom.pos
            pos = transform * pos if transform
            write_atom(io, atom, renumber ? (serial += 1) : atom.number, pos)
            atom_index_table[atom.number] = serial if renumber && !conect_options.none?
          end
          prev_res = residue
        end
        write_ter(io, prev_res, (serial += 1 if renumber)) if prev_res && (prev_res.polymer? || ter_on_fragment)
      end
    elsif ter_on_fragment
      atoms = struc.is_a?(AtomView) ? struc : struc.atoms
      atoms.each_fragment do |fragment|
        fragment.each do |atom|
          write_atom(io, atom, renumber ? (serial += 1) : atom.number, atom.pos)
          atom_index_table[atom.number] = serial if renumber && !conect_options.none?
        end
        write_ter(io, fragment[-1].residue, (serial += 1 if renumber))
      end
    else
      atoms = struc.is_a?(AtomView) ? struc : struc.atoms
      atoms.each do |atom|
        write_atom(io, atom, renumber ? (serial += 1) : atom.number, atom.pos)
        atom_index_table[atom.number] = serial if renumber && !conect_options.none?
      end
    end

    # write bonds if requested
    if !conect_options.none?
      # gather bonds to write
      bonds = struc.responds_to?(:bonds) ? struc.bonds : struc.atoms.bonds
      if conect_options != ConectOptions::All
        bonds.select! do |bond|
          a, b = bond.atoms
          ok = false
          ok ||= (a.protein? || a.water?) && (b.protein? || b.water?) if conect_options.standard?
          ok ||= (a.het? && !a.water?) || (b.het? && !b.water?) if conect_options.het?
          ok ||= a.sulfur? && b.sulfur? && a.residue != b.residue if conect_options.disulfide?
          ok
        end
      end

      # generate atom serial pairs for conect records
      idx_pairs = [] of Tuple(Int32, Int32)
      bonds.each do |bond|
        i, j = bond.atoms.map(&.number)
        i, j = {i, j}.map { |k| atom_index_table[k] } unless atom_index_table.empty?
        bond.order.to_i.times do
          idx_pairs << {i, j} << {j, i}
        end
      end

      # write conect records
      buffer = Array(Tuple(Int32, Int32)).new(4)
      idx_pairs.sort!.chunk(reuse: true, &.[0]).each do |i, pairs|
        pairs.each_slice(4, reuse: buffer) do |slice|
          io << "CONECT"
          Hybrid36.encode(io, i, width: 5)
          slice.each do |pair|
            Hybrid36.encode(io, pair[1], width: 5)
          end
          "\n".rjust io, 81 - 6 - 5 - slice.size * 5
        end
      end
    end

    io.printf "%-80s\n", "END" if include_end
  end

  # :ditto:
  def self.write(
    path : Path | String,
    struc : AtomView | Structure,
    conect conect_options : PDB::ConectOptions = PDB::ConectOptions.flags(Het, Disulfide),
    renumber : Bool = true,
    ter_on_fragment : Bool = false,
    include_header : Bool = true,
    include_end : Bool = true,
  ) : Nil
    File.open(path, "w") do |io|
      write(io, struc, conect_options, renumber, ter_on_fragment)
    end
  end

  # :ditto:
  def self.write(
    io : IO,
    structures : Enumerable(Structure),
    conect conect_options : PDB::ConectOptions = PDB::ConectOptions.flags(Het, Disulfide),
    renumber : Bool = true,
    ter_on_fragment : Bool = false,
  ) : Nil
    structures.each_with_index do |struc, i|
      if i == 0
        write_header(io, struc)
        io.printf "NUMMDL    %-4d%66s\n", structures.size, nil if structures.is_a?(Indexable)
      end
      io.printf "MODEL     %4d%66s\n", i + 1, nil
      write(io, struc, conect_options, renumber, ter_on_fragment, include_header: false, include_end: false)
      io.printf "%-80s\n", "ENDMDL"
    end
    io.printf "%-80s\n", "END"
  end

  # :ditto:
  def self.write(
    path : Path | String,
    structures : Enumerable(Structure),
    conect conect_options : PDB::ConectOptions = PDB::ConectOptions.flags(Het, Disulfide),
    renumber : Bool = true,
    ter_on_fragment : Bool = false,
  ) : Nil
    File.open(path, "w") do |io|
      write(io, structures, conect_options, renumber, ter_on_fragment)
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

  private def self.read_serial(pull : PullParser, start : Int, size : Int) : Int32
    read_serial?(pull, start, size) || pull.error("Invalid sequence number")
  end

  private def self.read_serial?(pull : PullParser, start : Int, size : Int) : Int32?
    pull.at?(start, size).str?.try do |str|
      Hybrid36.decode?(str)
    end
  end

  private def self.write_atom(io : IO, atom : Atom, serial : Int32, pos : Spatial::Vec3) : Nil
    io.printf "%-6s%5s %4s %-4s%s%4s%1s   %8.3f%8.3f%8.3f%6.2f%6.2f          %2s%2s\n",
      (atom.residue.protein? ? "ATOM" : "HETATM"),
      Hybrid36.encode(serial, width: 5),
      atom.name[..3].ljust(3),
      atom.residue.name[..3],
      atom.chain.id,
      Hybrid36.encode(atom.residue.number, width: 4),
      atom.residue.insertion_code,
      pos.x,
      pos.y,
      pos.z,
      atom.occupancy,
      atom.temperature_factor,
      atom.element.symbol,
      (sprintf("%+d", atom.formal_charge).reverse if atom.formal_charge != 0)
  end

  private def self.write_header(io : IO, atoms : AtomView) : Nil
    write_version(io)
  end

  private def self.write_header(io : IO, struc : Structure) : Nil
    if expt = struc.experiment
      io.printf "HEADER    %40s%9s   %4s              \n",
        nil,
        expt.deposition_date.to_s("%d-%^b-%y"),
        expt.pdb_accession.upcase
      method = expt.method.to_s.underscore.upcase.gsub('_', ' ').gsub("X RAY", "X-RAY")
      write_title(io, expt.title)
      io.printf "EXPDTA    %-70s\n", method
      io.printf "JRNL        DOI    %-61s\n", expt.doi.not_nil! if expt.doi
      write_version(io, code: expt.pdb_accession)
    else
      write_title(io, struc.title) unless struc.title.blank?
      write_version(io)
    end

    # write secondary structure records
    helix_id = sheet_id = 0
    struc.residues.secondary_structures
      .select!(&.[0].sec.regular?)
      .sort_by! do |residues|
        {residues[0].sec.beta_strand? ? 1 : -1, residues[0]}
      end
      .each do |residues|
        sec = residues[0].sec
        if sec.beta_strand?
          sheet_id += 1
          io.printf "SHEET  %3d %3s%2s %3s %1s%4d%1s %3s %1s%4d%1s%2s%40s\n",
            sheet_id, nil, nil, residues[0].name, residues[0].chain.id,
            residues[0].number, residues[0].insertion_code,
            residues[-1].name, residues[-1].chain.id,
            residues[-1].number, residues[-1].insertion_code, nil, nil
        else
          helix_id += 1
          helix_class = case sec
                        when .left_handed_helix3_10?    then 11
                        when .left_handed_helix_alpha?  then 6
                        when .left_handed_helix_gamma?  then 8
                        when .left_handed_helix_pi?     then 13
                        when .polyproline?              then 10
                        when .right_handed_helix3_10?   then 5
                        when .right_handed_helix_alpha? then 1
                        when .right_handed_helix_gamma? then 4
                        when .right_handed_helix_pi?    then 3
                        else                                 raise "BUG: unreachable"
                        end
          io.printf "HELIX  %3d %3d %3s %s %4d%1s %3s %s %4d%1s%2d%30s%6d    \n",
            helix_id, helix_id, residues[0].name, residues[0].chain.id,
            residues[0].number, residues[0].insertion_code,
            residues[-1].name, residues[-1].chain.id,
            residues[-1].number, residues[-1].insertion_code,
            helix_class, nil, residues.size
        end
      end

    # write unit cell if present
    if cell = struc.cell?
      a, b, c = cell.size
      alpha, beta, gamma = cell.angles
      io.printf "CRYST1%9.3f%9.3f%9.3f%7.2f%7.2f%7.2f %-11s%4d          \n",
        a, b, c, alpha, beta, gamma, "P 1", 1
    end
  end

  private def self.write_ter(io : IO, residue : Residue, serial : Int32?) : Nil
    io.printf "TER   %5s      %3s %s%4d%1s%53s\n",
      serial.to_s,
      residue.name,
      residue.chain.id,
      residue.number,
      residue.insertion_code,
      nil
  end

  private def self.write_title(io : IO, str : String) : Nil
    str.scan(/.{1,70}( |$)/).each_with_index do |match, i|
      io << "TITLE   "
      if i > 0
        io.printf "%2d %-69s\n", i + 1, match[0]
      else
        io.printf "  %-70s\n", match[0]
      end
    end
  end

  private def self.write_version(io : IO, code : String? = nil) : Nil
    io.printf "REMARK   4%-70s\n", nil
    # FIXME: update date. should be 31-NOV-12
    io.printf "REMARK   4 %4s COMPLIES WITH FORMAT V. 3.30, 13-JUL-11%25s\n",
      code.try(&.upcase),
      nil
  end
end
