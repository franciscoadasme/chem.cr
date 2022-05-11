@[Chem::RegisterFormat(ext: %w(.psf))]
module Chem::PSF
  class Reader
    include FormatReader(Topology)

    # :nodoc:
    FORMAT_COLUMN_SPANS = {
      "STANDARD" => [0..7, 9..12, 14..17, 19..22, 24..27, 29..32, 34..47, 48..61],
      "EXT"      => [0..9, 11..18, 20..27, 29..36, 38..45, 47..50, 52..65, 66..69],
    }

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new @io
      @atoms = [] of Atom
    end

    protected def decode_entry : Topology
      raise IO::EOFError.new if @pull.eof?

      @pull.error("Invalid PSF header") unless @pull.next_s? == "PSF"
      flags = @pull.line.split
      format = {"NAMD", "EXT"}.find(&.in?(flags)) || "STANDARD"
      @pull.next_line # skip empty line
      @pull.next_line
      n_remarks = @pull.next_i? || @pull.error("Invalid PSF header")
      @pull.error("Invalid PSF header") unless @pull.next_s? == "!NTITLE"
      n_remarks.times { @pull.next_line } # skip REMARKS lines

      @pull.skip_blank_lines

      n_atoms = parse_section_header "ATOM"
      top = Structure.build do |builder|
        prev_seg = nil
        n_atoms.times do
          @pull.next_line || @pull.error("Expected ATOM line")
          if cols = FORMAT_COLUMN_SPANS[format]?
            serial = @pull.at(cols[0]).int
            segment = @pull.at(cols[1]).str.strip
            resid = @pull.at(cols[2]).int
            resname = @pull.at(cols[3]).str.strip
            name = @pull.at(cols[4]).str.strip
            type = @pull.at(cols[5]).str.strip
            charge = @pull.at(cols[6]).float
            mass = @pull.at(cols[7]).float
          else # whitespace separated
            serial = @pull.next_i
            segment = @pull.next_s
            resid = @pull.next_i
            resname = @pull.next_s
            name = @pull.next_s
            type = @pull.next_s
            charge = @pull.next_f
            mass = @pull.next_f
          end

          builder.chain { } unless segment == prev_seg # force new chain
          builder.residue resname, resid
          atom = builder.atom name, serial, Spatial::Vec3.zero
          atom.type = type
          atom.partial_charge = charge
          atom.mass = mass
          @atoms << atom

          prev_seg = segment
        end
      end.topology

      parse_connectivity(Bond, "BOND").each do |bond|
        bond.atoms[0].bonds << bond
      end
      top.angles = parse_connectivity(Angle, "THETA")
      top.dihedrals = parse_connectivity(Dihedral, "PHI")
      top.impropers = parse_connectivity(Improper, "IMPHI")

      top
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
          @pull.next_line
          records_per_line.times do
            records << T.new(*tuple.map { @atoms[@pull.next_i - 1] })
          end
        end
      end
    end

    private def parse_section_header(title : String) : Int32
      n_records = @pull.next_i? || @pull.error("Invalid #{title} section header")
      unless @pull.next_s?.try(&.starts_with?("!N#{title}"))
        @pull.error("Invalid #{title} section header")
      end
      n_records
    end
  end
end
