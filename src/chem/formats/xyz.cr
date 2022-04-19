@[Chem::RegisterFormat(ext: %w(.xyz))]
module Chem::XYZ
  class Reader
    include FormatReader(Structure)
    include FormatReader::MultiEntry(Structure)

    def initialize(
      @io : IO,
      @guess_bonds : Bool = false,
      @guess_names : Bool = false,
      @sync_close : Bool = false
    )
      @pull = PullParser.new(@io)
    end

    protected def decode_entry : Structure
      raise IO::EOFError.new if @pull.eof?
      Structure.build(
        guess_bonds: @guess_bonds,
        guess_names: @guess_names,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
        use_templates: false,
      ) do |builder|
        n_atoms = @pull.next_i
        @pull.next_line
        builder.title @pull.line.strip
        @pull.next_line
        n_atoms.times do
          @pull.next_token
          ele = PeriodicTable[@pull.int? || @pull.str]? || @pull.error("Unknown element")
          vec = Spatial::Vec3.new @pull.next_f, @pull.next_f, @pull.next_f
          builder.atom ele, vec
          @pull.next_line
        end
      end
    end

    def skip_entry : Nil
      return if @pull.eof?
      n_atoms = @pull.next_i
      (n_atoms + 2).times { @pull.next_line }
    end
  end

  class Writer
    include FormatWriter(AtomCollection)
    include FormatWriter::MultiEntry(AtomCollection)

    protected def encode_entry(obj : AtomCollection) : Nil
      @io.puts obj.n_atoms
      @io.puts obj.is_a?(Structure) ? obj.title.gsub(/ *\n */, ' ') : ""
      obj.each_atom do |atom|
        @io.printf "%-3s%15.5f%15.5f%15.5f\n", atom.element.symbol, atom.x, atom.y, atom.z
      end
    end
  end
end
