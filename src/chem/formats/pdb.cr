# The PDB module provides capabilities for reading and writing RCSB
# Protein Data Bank (PDB) files.
#
# The PDB file format is a text-based fixed-column width format that
# stores atomic coordinates, crystallographic structure factors and NMR
# experimental data. Aside from coordinates, it may also includes the
# names of molecules, primary and secondary structure information,
# sequence database references, where appropriate, and ligand and
# biological assembly information, details about data collection and
# structure solution, and bibliographic citations. It is mainly focused
# on storing protein and nucleic acid structures. Further details found
# at the [PDB file format
# documentation](https://www.wwpdb.org/documentation/file-format)
# webpage.
#
# The PDB file format encodes one or more molecular structures and so
# the information is stored in `Structure` instances. The following
# information is read from/write to a PDB file:
#
# * Atomic coordinates
# * Bonding information (if present)
# * Topology information (chain->residue->atom)
# * Unit cell (if present)
# * Experiment data (if present)
# * Protein secondary structure (if present)
#
# Atom/residue numbers use the [hybrid-36](http://cci.lbl.gov/hybrid_36)
# representation to circumvent the hard numeric limits on the PDB file
# format. See the `PDB::Hybrid36` module.
#
# Registered file extensions for PDB are: `.ent` and `.pdb`.
#
# ### Reading PDB files
#
# The `PDB::Reader` class reads PDB entries sequentially from an `IO` or
# file. Use either the `#each` method to yield every entry or
# `#read_next` method to read the next entry only.
#
# ```
# PDB::Reader.open("/path/to/pdb") do |reader|
#   reader.each do |structure|
#     ...
#   end
#
#   # or
#
#   while structure = reader.read_next
#     .
#   end
# end
# ```
#
# Alternatively, use the convenience `Structure.from_pdb` and
# `Array.from_pdb` methods to read the first or all entries in a PDB
# file, respectively.
#
# ```
# Structure.from_pdb "/path/to/pdb" # => <Structure ...>
# # or
# Array(Structure).from_pdb "/path/to/pdb" # => [<Structure ...>, ...]
# ```
#
# Similarly, the general `Structure#read` method can be used to read a
# PDB file, but the file format is determined on runtime.
#
# ### Writing PDB files
#
# The `PDB::Writer` class writes PDB entries sequentially to an `IO` or
# file. Use the `#write` method to write an instance of a compatible
# type. It can be called multiple times.
#
# ```
# PDB::Writer.open("/path/to/pdb") do |writer|
#   writer.write structure1
#   writer.write structure2
#   ...
# end
# ```
#
# Alternatively, use the convenience `Structure#to_pdb` methods to write
# a single entry in a PDB file.
#
# ```
# structure = Structure.build do |builder|
#   ...
# end
# structure.to_pdb "/path/to/pdb"
# ```
@[Chem::FileType(ext: %w(ent pdb))]
module Chem::PDB
  # The `PDB::Hybrid36` module provides capabilities for the encoding
  # and decoding of numbers in the
  # [hybrid-36](http://cci.lbl.gov/hybrid_36) representation.
  #
  # The PDB file format cannot accomodate atom serial and residue
  # sequence numbers larger than 99,999 (5 characters) and 9,999 (4
  # characters), respectively, due to the fixed-column width format. In
  # contrast, the hybrid-36 counting system accommodates up to
  # 87,440,031 and 2,436,111 using 5 and 4 characters, respectively. The
  # hybrid-36 format is backward compatible with the formal PDB
  # specification, where the distinction between "standard" and
  # "extended" PDB files becomes evident beyond the PDB's hard limit,
  # e.g.:
  #
  # ```text
  # ATOM  99998  SD  MET L9999      48.231 -64.383  -9.257  1.00 11.54
  # ATOM  99999  CE  MET L9999      49.398 -63.242 -10.211  1.00 14.60
  # ATOM  A0000  N   VAL LA000      52.228 -67.689 -12.196  1.00  8.76
  # ATOM  A0001  CA  VAL LA000      53.657 -67.774 -12.458  1.00  3.40
  # ```
  module Hybrid36
    # Returns the result of interpreting *str* as an integer using the
    # hybrid-36 representation. Returns zero for a blank string. Raises
    # `ArgumentError` if *str* couldn't be interpreted as a number.
    #
    # ```
    # PDB::Hybrid36.decode "    "  # => 0
    # PDB::Hybrid36.decode "-999"  # => -999
    # PDB::Hybrid36.decode "5959"  # => 5959
    # PDB::Hybrid36.decode "9999"  # => 9999
    # PDB::Hybrid36.decode "A000"  # => 10000
    # PDB::Hybrid36.decode "A001"  # => 10001
    # PDB::Hybrid36.decode "ZZZZ"  # => 1223055
    # PDB::Hybrid36.decode "a000"  # => 1223056
    # PDB::Hybrid36.decode " a000" # raises ArgumentError
    # PDB::Hybrid36.decode "abc"   # raises ArgumentError
    # ```
    def self.decode(str : String) : Int32
      decode?(str) || invalid_literal str
    end

    # Returns the result of interpreting *str* as an integer using the
    # hybrid-36 representation. Returns zero for a blank string. Returns
    # `nil` if *str* couldn't be interpreted as a number.
    #
    # ```
    # PDB::Hybrid36.decode? "    "  # => 0
    # PDB::Hybrid36.decode? "-999"  # => -999
    # PDB::Hybrid36.decode? "5959"  # => 5959
    # PDB::Hybrid36.decode? "9999"  # => 9999
    # PDB::Hybrid36.decode? "A000"  # => 10000
    # PDB::Hybrid36.decode? "A001"  # => 10001
    # PDB::Hybrid36.decode? "ZZZZ"  # => 1223055
    # PDB::Hybrid36.decode? "a000"  # => 1223056
    # PDB::Hybrid36.decode? " a000" # => nil
    # PDB::Hybrid36.decode? "abc"   # => nil
    # ```
    def self.decode?(str : String) : Int32?
      return 0 if str.blank?

      chr = str[0]
      return str.to_i? if chr == '-' || chr == ' ' || chr.ascii_number?
      if num = str.to_i?(base: 36)
        width = str.bytesize
        case chr
        when .ascii_uppercase? then num - 10*36**(width - 1) + 10**width
        when .ascii_lowercase? then num + 16*36**(width - 1) + 10**width
        end
      end
    end

    # Returns the result of encoding *num* in the hybrid-36
    # representation. Raises `ArgumentError` if *num* is out of range.
    #
    # *width* indicates the number of characters used for encoding,
    # which dictates the smallest and largest value possible to be
    # encoded.
    #
    # ```
    # PDB::Hybrid36.encode 123, width: 4        # => " 123"
    # PDB::Hybrid36.encode 1234, width: 4       # => "1234"
    # PDB::Hybrid36.encode 9999, width: 4       # => "9999"
    # PDB::Hybrid36.encode 10_000, width: 4     # => "A000"
    # PDB::Hybrid36.encode 10_004, width: 4     # => "A004"
    # PDB::Hybrid36.encode 45_449_632, width: 5 # => "b0000"
    # PDB::Hybrid36.encode -9999, width: 4      # raises ArgumentError
    # PDB::Hybrid36.encode 2_436_112, width: 4  # raises ArgumentError
    # ```
    def self.encode(num : Int, width : Int) : String
      String.build do |io|
        encode io, num, width
      end
    end

    # Writes the result of encoding *num* in the hybrid-36
    # representation to *io*. Raises `ArgumentError` if *num* is out of
    # range.
    #
    # *width* indicates the number of characters used for encoding,
    # which dictates the smallest and largest value possible to be
    # encoded.
    #
    # ```
    # io = IO::Memory.new
    # PDB::Hybrid36.encode io, 123, width: 4
    # io.puts
    # PDB::Hybrid36.encode io, 9999, width: 4
    # io.puts
    # PDB::Hybrid36.encode io, 10_000, width: 4
    # io.puts
    # PDB::Hybrid36.encode io, 10_004, width: 4
    # io.puts
    # PDB::Hybrid36.encode io, 45_449_632, width: 5
    # io.puts
    # puts io.to_s
    # ```
    #
    # Prints:
    #
    # ```text
    # 123
    # 1234
    # 9999
    # A000
    # A004
    # b0000
    # ```
    #
    # Out of range values fail to be encoded:
    #
    # ```
    # PDB::Hybrid36.encode io, -9999, width: 4     # raises ArgumentError
    # PDB::Hybrid36.encode io, 2_436_112, width: 4 # raises ArgumentError
    # ```
    def self.encode(io : IO, num : Int, width : Int) : Nil
      out_of_range num if num < 1 - 10**(width - 1)
      return io.printf "%#{width}d", num if num < 10**width
      num -= 10**width
      return (num + 10*36**(width - 1)).to_s io, base: 36, upcase: true if num < 26*36**(width - 1)
      num -= 26*36**(width - 1)
      return (num + 10*36**(width - 1)).to_s io, base: 36 if num < 26*36**(width - 1)
      out_of_range num
    end

    # Raises `ArgumentError` for invalid literals
    private def self.invalid_literal(str : String)
      raise ArgumentError.new "Invalid number literal: #{str}"
    end

    # Raises `ArgumentError` for a value out of range
    private def self.out_of_range(num : Int)
      raise ArgumentError.new "Value out of range"
    end
  end

  # Writes entries sequentially to a PDB file. The current
  # implementation conforms to the [PDB format
  # v3.3](https://www.wwpdb.org/documentation/file-format-content/format33/v3.3.html).
  #
  # ```
  # PDB::Writer.open("/path/to/pdb") do |writer|
  #   writer.write structure1
  #   writer.write structure2
  #   ...
  # end
  # ```
  #
  # Atom/residue numbers are written in the
  # [hybrid-36](http://cci.lbl.gov/hybrid_36) representation. See the
  # `PDB::Hybrid36` module.
  class Writer
    include FormatWriter(AtomCollection)
    include FormatWriter(Structure)

    private PDB_VERSION      = "3.30"
    private PDB_VERSION_DATE = Time.local 2011, 7, 13
    private WHITESPACE       = ' '

    # Writes CONECT records for the given bonds. If `true`, write all
    # bonds in the given structure or compatible instance.
    needs bonds : Bool | Array(Bond) = false
    # If `true`, atom serial numbers will start from 1 upon writing
    # instead of the current atom numbering.
    needs renumber : Bool = true

    @atom_index_table = {} of Int32 => Int32
    @record_index = 0
    @model = 0

    def close : Nil
      write_bonds
      @io.printf "%-80s\n", "END"
      super
    end

    # Write the atoms in *atoms* sequentially to the `IO` encoded in the
    # PDB file format.
    #
    # NOTE: original alternate location is not written.
    def write(atoms : AtomCollection) : Nil
      check_open
      @record_index = 0
      @bonds = atoms.bonds if @bonds == true

      write_pdb_version if @model == 0

      atoms.each_atom { |atom| write atom }

      @model += 1
    end

    # Write the atoms in *structure* sequentially to the `IO` encoded in
    # the PDB file format.
    #
    # Experiment, secondary structure and unit cell information is
    # written in the header if present. `TER` records are written after
    # each polymer chain.
    #
    # NOTE: original alternate location is not written.
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

  # Reads the entries sequentially in a PDB file. Use either the `#each`
  # method to yield every entry or `#read_next` method to read the next
  # entry only.
  #
  # ```
  # PDB::Reader.open("/path/to/pdb") do |reader|
  #   reader.each do |structure|
  #     ...
  #   end
  #
  #   # or
  #
  #   while structure = reader.read_next
  #     ...
  #   end
  # end
  # ```
  #
  # This implementation supports for alternate locations on both atom
  # positions and residue types, where the latter implies that the
  # number of atoms may vary among the alternate locations of the same
  # residue. However, alternate location information is not stored after
  # reading.
  #
  # Atom/residue numbers are decoded using the
  # [hybrid-36](http://cci.lbl.gov/hybrid_36) representation. See the
  # `PDB::Hybrid36` module.
  #
  # NOTE: The current implementation conforms to the [PDB format
  # v3.3](https://www.wwpdb.org/documentation/file-format-content/format33/v3.3.html).
  # Files that use an older specification may fail to read.
  class Reader
    include FormatReader(Structure)
    include MultiFormatReader(Structure)
    include TextFormatReader

    private alias ResidueId = Tuple(Char, Int32, Char?)
    private alias Sec = Protein::SecondaryStructure

    # :nodoc:
    HELIX_TYPES = {
      1 => Sec::RightHandedHelixAlpha,
      3 => Sec::RightHandedHelixPi,
      5 => Sec::RightHandedHelix3_10,
    }

    # Alternate location to read only. If `nil`, the atom positions and
    # topology information of each residue with multiple alternate
    # locations will be set to that of highest occupancy.
    needs alt_loc : Char? = nil
    # List of chain identifiers to read. If present, other chains will
    # be discarded. Use the special value `"first"` to select the first
    # chain regardless of its identifier.
    needs chains : Enumerable(Char) | String | Nil = nil
    # Triggers bond and topology perception after reading. See
    # `Structure::Builder#build` for more information.
    needs guess_topology : Bool = true
    # Indicates whether to read HET atoms.
    needs het : Bool = true

    @pdb_bonds = Hash(Tuple(Int32, Int32), Int32).new 0
    @pdb_expt : Structure::Experiment?
    @pdb_lattice : Lattice?
    @pdb_seq : Protein::Sequence?
    @pdb_title = ""
    @pdb_header = false

    @alt_locs : Hash(Residue, Array(AlternateLocation))?
    @builder = uninitialized Structure::Builder
    @seek_bonds = true
    @sec = [] of Tuple(Protein::SecondaryStructure, ResidueId, ResidueId)

    def read_next : Structure?
      check_open
      return if @io.skip_whitespace.eof? || @io.check("END", "MASTER")
      read_header unless @pdb_header
      unless @io.skip_whitespace.check("ATOM", "HETATM", "MODEL")
        parse_exception "Empty content"
      end

      @io.skip_line if @io.check("MODEL")
      @builder = Structure::Builder.new guess_topology: @guess_topology
      @builder.title @pdb_title
      @builder.lattice @pdb_lattice
      @builder.expt @pdb_expt
      @builder.seq @pdb_seq

      @pdb_bonds.clear
      @serial = 0
      until @io.eof?
        break if @io.skip_whitespace.check("END", "MODEL", "MASTER")

        case line = @io.read_line
        when .starts_with?("ATOM")
          read_atom line
        when .starts_with?("HETATM")
          read_atom(line) if read_het?
        when .starts_with?("CONECT")
          read_bonds line
        end
      end
      @io.skip_line if @io.check("ENDMDL")

      resolve_alternate_locations unless @alt_loc
      assign_bonds
      assign_secondary_structure

      @builder.build
    end

    def skip : Nil
      read_header unless @pdb_header
      @io.skip_line if @io.skip_whitespace.check("MODEL")
      until @io.eof?
        case @io.skip_whitespace
        when .check("ENDMDL")
          @io.skip_line
          break
        when .check("MODEL", "END", "MASTER")
          break
        else
          @io.skip_line
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

    private def assign_bonds : Nil
      @builder.bonds @pdb_bonds unless @pdb_bonds.empty?
    end

    private def assign_secondary_structure : Nil
      @sec.each do |(sec, ri, rj)|
        @builder.secondary_structure ri, rj, sec
      end
    end

    private def read_atom(line : String) : Nil
      alt_loc = line[16].presence
      return if @alt_loc && alt_loc && alt_loc != @alt_loc

      chid = line[21]
      case chains = @chains
      when Enumerable then return unless chid.in?(chains)
      when "first"    then return if chid != (@builder.current_chain.try(&.id) || chid)
      end

      ele = case symbol = line[76, 2]?.presence.try(&.strip)
            when "D"    then PeriodicTable::D
            when "X"    then PeriodicTable::X
            when String then PeriodicTable[symbol]
            end

      @builder.chain chid if chid.alphanumeric?
      resname = line[17, 4].strip
      @builder.residue resname, Hybrid36.decode(line[22, 4]), line[26].presence
      atom = @builder.atom \
        line[12, 4].strip,
        Hybrid36.decode(line[6, 5]),
        Spatial::Vector.new(line[30, 8].to_f, line[38, 8].to_f, line[46, 8].to_f),
        element: ele,
        formal_charge: line[78, 2]?.try(&.reverse.to_i?) || 0,
        occupancy: line[54, 6]?.presence.try(&.to_f) || 0.0,
        temperature_factor: line[60, 6]?.presence.try(&.to_f) || 0.0

      alt_loc(atom.residue, alt_loc, resname) << atom if !@alt_loc && alt_loc
    end

    private def read_bonds(line : String) : Nil
      i = Hybrid36.decode line[6, 5]
      (11..).step(5).each do |start|
        break unless j = line[start, 5]?.presence.try { |str| Hybrid36.decode(str) }
        @pdb_bonds[{i, j}] += 1 unless i > j # skip redundant bonds
      end
    end

    private def read_header
      aminoacids = [] of Protein::AminoAcid
      date = doi = pdbid = resolution = nil
      method = Structure::Experiment::Method::XRayDiffraction
      title = ""

      until @io.eof?
        break if @io.skip_whitespace.check("ATOM", "HETATM", "MODEL")

        case line = @io.read_line
        when .starts_with?("CRYST1")
          size = Spatial::Size.new line[6, 9].to_f, line[15, 9].to_f, line[24, 9].to_f
          @pdb_lattice = Lattice.new size, line[33, 7].to_f, line[40, 7].to_f, line[47, 7].to_f
        when .starts_with?("EXPDTA")
          str = line[10, 70].split(';')[0].delete "- "
          method = Structure::Experiment::Method.parse str
        when .starts_with?("HEADER")
          date = line[50, 9]?.try { |str| Time.parse_utc str, "%d-%^b-%y" }
          pdbid = line[62, 4]?.presence
        when .starts_with?("HELIX")
          sec = HELIX_TYPES[line[38, 2].to_i]? || parse_exception "Invalid helix type"
          ri = {line[19], Hybrid36.decode(line[21, 4]), line[25].presence}
          rj = {line[31], Hybrid36.decode(line[33, 4]), line[37].presence}
          parse_exception "Different chain ids in HELIX record" if ri[0] != rj[0]
          @sec << {sec, ri, rj}
        when .starts_with?("JRNL")
          case line[12, 4].strip
          when "DOI" then doi = line[19, 60].strip
          end
        when .starts_with?("REMARK")
          case line[7, 3].presence.try(&.lstrip)
          when "2"
            resolution = line[23, 7].to_f?
          when nil
            pdbid = line[11, 4].presence
            date = Time::UNIX_EPOCH if pdbid
          end
        when .starts_with?("SEQRES")
          if @chains.nil? || @chains.try(&.includes?(line[11]))
            line[19, 60].split.each do |resname|
              aminoacids << Protein::AminoAcid[resname]
            end
          end
        when .starts_with?("SHEET")
          ri = {line[21], Hybrid36.decode(line[22, 4]), line[26].presence}
          rj = {line[21], Hybrid36.decode(line[33, 4]), line[37].presence}
          parse_exception "Different chain ids in SHEET record" if ri[0] != rj[0]
          @sec << {Sec::BetaStrand, ri, rj}
        when .starts_with?("TITLE")
          title += line[10, 70].rstrip.squeeze ' '
        end
      end

      if date && pdbid
        @pdb_expt = Structure::Experiment.new title, method, resolution, pdbid, date, doi
        @pdb_title = pdbid
      else
        @pdb_title = title
      end
      @pdb_seq = Protein::Sequence.new aminoacids unless aminoacids.empty?

      @pdb_header = true
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
