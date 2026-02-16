@[Chem::RegisterFormat(ext: %w(.psf), module_api: true)]
module Chem::PSF
  # Reads the structure from *io*.
  # Supports the standard, extended, and NAMD variants.
  #
  # Atom positions are set to zero.
  def self.read(io : IO) : Structure
    pull = PullParser.new(io)
    raise IO::EOFError.new if pull.eof?

    pull.error("Invalid PSF header") unless pull.next_s? == "PSF"
    flags = pull.rest_of_line.split
    variant = flags.compact_map { |f| Variant.parse?(f) }.first? || Variant::Standard
    pull.consume_line # skip empty line
    pull.consume_line

    n_remarks = pull.next_i? || pull.error("Invalid PSF header")
    pull.error("Invalid PSF header") unless pull.next_s? == "!NTITLE"
    pull.consume_line
    n_remarks.times { pull.consume_line } # skip REMARKS lines

    pull.skip_blank_lines

    n_atoms = parse_section_header(pull, "ATOM")
    atoms = [] of Atom
    structure = Structure.build do |builder|
      prev_seg = nil
      n_atoms.times do
        case variant
        in .standard?
          number = pull.at(0..7).int
          segment = pull.at(9..12).str.strip
          resid = pull.at(14..17).int
          resname = pull.at(19..22).str.strip
          name = pull.at(24..27).str.strip
          typename = pull.at(29..32).str.strip
          charge = pull.at(34..47).float
          mass = pull.at(48..61).float
        in .extended? # longer (wider columns) numbers and names
          number = pull.at(0..9).int
          segment = pull.at(11..18).str.strip
          resid = pull.at(20..27).int
          resname = pull.at(29..36).str.strip
          name = pull.at(38..45).str.strip
          typename = pull.at(47..50).str.strip
          charge = pull.at(52..65).float
          mass = pull.at(66..79).float
        in .namd? # whitespace separated
          number = pull.next_i
          segment = pull.next_s
          resid = pull.next_i
          resname = pull.next_s
          name = pull.next_s
          typename = pull.next_s
          charge = pull.next_f
          mass = pull.next_f
        end

        builder.chain { } unless segment == prev_seg # force new chain
        builder.residue resname, resid
        atom = builder.atom name, number, Spatial::Vec3.zero
        atom.typename = typename
        atom.partial_charge = charge
        atom.mass = mass
        atoms << atom

        prev_seg = segment
        pull.consume_line
      end
    end

    parse_connectivity(pull, Bond, "BOND", atoms).each do |bond|
      bond.atoms[0].bonds << bond
    end
    structure.angles = parse_connectivity(pull, Angle, "THETA", atoms)
    structure.dihedrals = parse_connectivity(pull, Dihedral, "PHI", atoms)
    structure.impropers = parse_connectivity(pull, Improper, "IMPHI", atoms)

    structure
  end

  # :ditto:
  def self.read(path : Path | String) : Structure
    File.open(path) do |file|
      read(file)
    end
  end

  # :nodoc:
  enum Variant
    Standard
    Extended
    NAMD

    def self.parse?(str : String) : self?
      case str.camelcase.downcase
      when "standard"        then Standard
      when "ext", "extended" then Extended
      when "namd"            then NAMD
      else                        nil
      end
    end
  end

  private def self.parse_connectivity(pull : PullParser, type : T.class, title : String, atoms : Array(Atom)) : Array(T) forall T
    pull.skip_blank_lines
    n_records = parse_section_header(pull, title)
    parse_records(pull, type, n_records, atoms)
  end

  private def self.parse_records(pull : PullParser, type : Bond.class, size : Int, atoms : Array(Atom)) : Array(Bond)
    parse_records(pull, Bond, {Int32, Int32}, size, atoms)
  end

  private def self.parse_records(pull : PullParser, type : Angle.class, size : Int, atoms : Array(Atom)) : Array(Angle)
    parse_records(pull, Angle, {Int32, Int32, Int32}, size, atoms)
  end

  private def self.parse_records(pull : PullParser, type : Dihedral.class, size : Int, atoms : Array(Atom)) : Array(Dihedral)
    parse_records(pull, Dihedral, {Int32, Int32, Int32, Int32}, size, atoms)
  end

  private def self.parse_records(pull : PullParser, type : Improper.class, size : Int, atoms : Array(Atom)) : Array(Improper)
    parse_records(pull, Improper, {Int32, Int32, Int32, Int32}, size, atoms)
  end

  private def self.parse_records(pull : PullParser, type : T.class, tuple : Tuple, size : Int, atoms : Array(Atom)) : Array(T) forall T
    records_per_line = (8 / tuple.size).ceil.to_i
    n_lines = (size / records_per_line).ceil.to_i
    remaining = size
    Array(T).new(size).tap do |records|
      n_lines.times do
        records_per_line.times do
          break unless remaining > 0
          records << T.new(*tuple.map { atoms[pull.next_i - 1] })
          remaining -= 1
        end
        pull.consume_line
      end
    end
  end

  private def self.parse_section_header(pull : PullParser, title : String) : Int32
    n_records = pull.next_i? || pull.error("Invalid #{title} section header")
    unless pull.next_s?.try(&.starts_with?("!N#{title}"))
      pull.error("Invalid #{title} section header")
    end
    pull.consume_line
    n_records
  end
end
