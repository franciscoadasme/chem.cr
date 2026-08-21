@[Chem::RegisterFormat(ext: %w(.psf))]
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
    source_file = (file = io).is_a?(File) ? file.path : nil
    struc = Structure.new(source_file)
    chain = Chain.new(struc, Chain.succ_id)
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

      # A new segment starts a new chain (A, B, …), not a chain named
      # after the segment.
      if prev_seg && segment != prev_seg
        chain = Chain.new(struc, chain.succ_id)
      end
      residue = chain[resid]? || Residue.new(chain, resid, resname)
      Atom.new(residue, name, Spatial::Vec3.zero,
        number: number,
        typename: typename,
        partial_charge: charge,
        mass: mass)

      prev_seg = segment
      pull.consume_line
    end

    pull.skip_blank_lines
    n_bonds = parse_section_header(pull, "BOND")
    remaining = n_bonds
    ((n_bonds / 4).ceil.to_i).times do
      4.times do
        break unless remaining > 0
        struc.atoms[pull.next_i - 1].bonds.add struc.atoms[pull.next_i - 1]
        remaining -= 1
      end
      pull.consume_line
    end

    struc
  end

  define_file_overload(PSF, read)

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

  private def self.parse_section_header(pull : PullParser, title : String) : Int32
    n_records = pull.next_i? || pull.error("Invalid #{title} section header")
    unless pull.next_s?.try(&.starts_with?("!N#{title}"))
      pull.error("Invalid #{title} section header")
    end
    pull.consume_line
    n_records
  end
end
