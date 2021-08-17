@[Chem::RegisterFormat(ext: %w(.xyz))]
module Chem::XYZ
  class Writer
    include FormatWriter(AtomCollection)
    include FormatWriter::MultiEntry(AtomCollection)

    protected def encode_entry(atoms : AtomCollection, title : String = "") : Nil
      @io.puts atoms.n_atoms
      @io.puts title.gsub(/ *\n */, ' ')
      atoms.each_atom do |atom|
        @io.printf "%-3s%15.5f%15.5f%15.5f\n", atom.element.symbol, atom.x, atom.y, atom.z
      end
    end

    protected def encode_entry(structure : Structure) : Nil
      encode_entry structure, structure.title
    end
  end

  class Reader
    include FormatReader(Structure)
    include FormatReader::MultiEntry(Structure)

    def initialize(io : IO, @guess_topology : Bool = true, @sync_close : Bool = false)
      @io = TextIO.new io
    end

    protected def decode_entry : Structure
      @io.skip_whitespace
      raise IO::EOFError.new if @io.eof?
      Structure.build(@guess_topology) do |builder|
        n_atoms = @io.read_int
        @io.skip_line
        builder.title @io.read_line.strip
        n_atoms.times do
          builder.atom PeriodicTable[@io.read_word], @io.read_vector
          @io.skip_line
        end
      end
    end

    def skip_entry : Nil
      @io.skip_whitespace
      return if @io.eof?
      n_atoms = @io.read_int
      (n_atoms + 2).times { @io.skip_line }
    end
  end
end
