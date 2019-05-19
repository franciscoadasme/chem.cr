module Chem
  class Structure
    include AtomCollection
    include ChainCollection
    include ResidueCollection

    @chain_table = {} of Char => Chain
    @chains = [] of Chain

    getter biases = [] of Chem::Bias
    property experiment : Protein::Experiment?
    property lattice : Lattice?
    property sequence : Protein::Sequence?
    property title : String = ""

    delegate :[], :[]?, to: @chain_table

    def self.build(&block) : self
      builder = Structure::Builder.new
      with builder yield builder
      builder.build
    end

    def self.parse(io : ::IO | String,
                   format : IO::FileFormat | Symbol,
                   **options) : Structure
      format = IO::FileFormat.parse(format.to_s) if format.is_a? Symbol
      format.parser(io, **options).parse
    end

    def self.read(filepath : String,
                  format : IO::FileFormat | Symbol,
                  **options) : Structure
      parse File.read(filepath), format, **options
    end

    def self.read(filepath : String, **options) : Structure
      format = IO::FileFormat.from_ext File.extname(filepath)
      read filepath, format, **options
    end

    protected def <<(chain : Chain) : self
      @chains << chain
      @chain_table[chain.id] = chain
      self
    end

    def coords : Spatial::CoordinatesProxy
      Spatial::CoordinatesProxy.new self, @lattice
    end

    def delete(chain : Chain) : Chain?
      chain = @chains.delete chain
      @chain_table.delete(chain.id) if chain
      chain
    end

    def each_atom : Iterator(Atom)
      iterators = [] of Iterator(Atom)
      each_chain do |chain|
        chain.each_residue do |residue|
          iterators << residue.each_atom
        end
      end
      Iterator.chain iterators
    end

    def each_atom(&block : Atom ->)
      @chains.each do |chain|
        chain.each_atom do |atom|
          yield atom
        end
      end
    end

    def each_chain : Iterator(Chain)
      @chains.each
    end

    def each_chain(&block : Chain ->)
      @chains.each do |chain|
        yield chain
      end
    end

    def each_residue : Iterator(Residue)
      Iterator.chain each_chain.map(&.each_residue).to_a
    end

    def each_residue(&block : Residue ->)
      @chains.each do |chain|
        chain.each_residue do |residue|
          yield residue
        end
      end
    end

    def empty?
      size == 0
    end

    def inspect(io : ::IO)
      to_s io
    end

    def size : Int32
      each_atom.sum(0) { 1 }
    end

    def to_s(io : ::IO)
      io << "<Structure"
      io << " " << title.inspect unless title.blank?
      io << ": "
      io << size << " atoms"
      io << ", " << residues.size << " residues" if residues.size > 1
      io << ", "
      io << "non-" unless @lattice
      io << "periodic>"
    end

    def unwrap : self
      if lattice = @lattice
        Spatial::PBC.unwrap self, lattice
        self
      else
        raise Error.new "Cannot wrap a non-periodic structure"
      end
    end

    def wrap(around center : Spatial::Vector? = nil) : self
      if lattice = @lattice
        Spatial::PBC.wrap self, lattice, center || lattice.center
        self
      else
        raise Error.new "Cannot wrap a non-periodic structure"
      end
    end

    def write(io : ::IO, format : IO::FileFormat | Symbol, **options) : Nil
      format = IO::FileFormat.parse(format.to_s) if format.is_a? Symbol
      format.writer(io, **options) << self
    end

    def write(filepath : String, format : IO::FileFormat | Symbol, **options) : Nil
      File.open(filepath, mode: "w") do |file|
        write file, format, **options
      end
    end

    def write(filepath : String, **options) : Nil
      format = IO::FileFormat.from_ext File.extname(filepath)
      write filepath, format, **options
    end

    protected def reset_cache : Nil
      @chain_table.clear
      @chains.sort_by! &.id
      @chains.each do |chain|
        @chain_table[chain.id] = chain
      end
    end
  end
end
