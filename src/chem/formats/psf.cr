@[Chem::RegisterFormat(ext: %w(.psf))]
module Chem::PSF
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

  class Reader
    include FormatReader(Structure)

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new @io
      @atoms = [] of Atom
    end

    protected def decode_entry : Structure
      raise IO::EOFError.new if @pull.eof?

      @pull.error("Invalid PSF header") unless @pull.next_s? == "PSF"
      flags = @pull.rest_of_line.split
      variant = flags.compact_map { |f| Variant.parse?(f) }.first? || Variant::Standard
      @pull.consume_line # skip empty line
      @pull.consume_line

      n_remarks = @pull.next_i? || @pull.error("Invalid PSF header")
      @pull.error("Invalid PSF header") unless @pull.next_s? == "!NTITLE"
      @pull.consume_line
      n_remarks.times { @pull.consume_line } # skip REMARKS lines

      @pull.skip_blank_lines

      n_atoms = parse_section_header "ATOM"
      structure = Structure.build do |builder|
        prev_seg = nil
        n_atoms.times do
          case variant
          in .standard?
            serial = @pull.at(0..7).int
            segment = @pull.at(9..12).str.strip
            resid = @pull.at(14..17).int
            resname = @pull.at(19..22).str.strip
            name = @pull.at(24..27).str.strip
            typename = @pull.at(29..32).str.strip
            charge = @pull.at(34..47).float
            mass = @pull.at(48..61).float
          in .extended? # longer (wider columns) numbers and names
            serial = @pull.at(0..9).int
            segment = @pull.at(11..18).str.strip
            resid = @pull.at(20..27).int
            resname = @pull.at(29..36).str.strip
            name = @pull.at(38..45).str.strip
            typename = @pull.at(47..50).str.strip
            charge = @pull.at(52..65).float
            mass = @pull.at(66..79).float
          in .namd? # whitespace separated
            serial = @pull.next_i
            segment = @pull.next_s
            resid = @pull.next_i
            resname = @pull.next_s
            name = @pull.next_s
            typename = @pull.next_s
            charge = @pull.next_f
            mass = @pull.next_f
          end

          builder.chain { } unless segment == prev_seg # force new chain
          builder.residue resname, resid
          atom = builder.atom name, serial, Spatial::Vec3.zero
          atom.typename = typename
          atom.partial_charge = charge
          atom.mass = mass
          @atoms << atom

          prev_seg = segment
          @pull.consume_line
        end
      end

      parse_connectivity(Bond, "BOND").each do |bond|
        bond.atoms[0].bonds << bond
      end
      structure.angles = parse_connectivity(Angle, "THETA")
      structure.dihedrals = parse_connectivity(Dihedral, "PHI")
      structure.impropers = parse_connectivity(Improper, "IMPHI")

      structure
    end

    private def parse_connectivity(type : T.class, title : String) : Array(T) forall T
      @pull.skip_blank_lines
      n_records = parse_section_header title
      parse_records type, n_records
    end

    private def parse_records(type : Bond.class, size : Int) : Array(Bond)
      parse_records Bond, {Int32, Int32}, size
    end

    private def parse_records(type : Angle.class, size : Int) : Array(Angle)
      parse_records Angle, {Int32, Int32, Int32}, size
    end

    private def parse_records(type : Dihedral.class, size : Int) : Array(Dihedral)
      parse_records Dihedral, {Int32, Int32, Int32, Int32}, size
    end

    private def parse_records(type : Improper.class, size : Int) : Array(Improper)
      parse_records Improper, {Int32, Int32, Int32, Int32}, size
    end

    private def parse_records(type : T.class, tuple : Tuple, size : Int) : Array(T) forall T
      records_per_line = (8 / tuple.size).ceil.to_i
      n_lines = (size / records_per_line).ceil.to_i
      Array(T).new(size).tap do |records|
        n_lines.times do
          records_per_line.times do
            break unless size > 0
            records << T.new(*tuple.map { @atoms[@pull.next_i - 1] })
            size -= 1
          end
          @pull.consume_line
        end
      end
    end

    private def parse_section_header(title : String) : Int32
      n_records = @pull.next_i? || @pull.error("Invalid #{title} section header")
      unless @pull.next_s?.try(&.starts_with?("!N#{title}"))
        @pull.error("Invalid #{title} section header")
      end
      @pull.consume_line
      n_records
    end
  end
end
