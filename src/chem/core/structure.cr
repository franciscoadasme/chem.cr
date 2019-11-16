module Chem
  class Structure
    include AtomCollection
    include ChainCollection
    include ResidueCollection

    @chain_table = {} of Char => Chain
    @chains = [] of Chain

    getter biases = [] of Chem::Bias
    property experiment : Structure::Experiment?
    property lattice : Lattice?
    property sequence : Protein::Sequence?
    property title : String = ""

    delegate :[], :[]?, to: @chain_table

    def self.build(&block) : self
      builder = Topology::Builder.new
      with builder yield builder
      builder.build
    end

    macro finished
      {% for parser in Parser.subclasses.select(&.annotation(IO::FileType)) %}
        {% format = parser.annotation(IO::FileType)[:format].id.underscore %}

        def self.from_{{format.id}}(input : ::IO | Path | String, **options) : self
          {{parser}}.new(input, **options).first? || raise IO::ParseException.new("Empty content")
        end
      {% end %}
    end

    def self.read(path : Path | String) : self
      format = IO::FileFormat.from_ext File.extname(path)
      path = Path[path] unless path.is_a?(Path)
      {% begin %}
        case format
        {% for parser in Parser.subclasses.select(&.annotation(IO::FileType)) %}
          {% format = parser.annotation(IO::FileType)[:format].id.underscore %}
          when .{{format.id}}?
            from_{{format.id}} path
        {% end %}
        else
          raise "No parser associated with file format #{format}"
        end
      {% end %}
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

    def dig(id : Char) : Chain
      self[id]
    end

    def dig(id : Char, *subindexes)
      self[id].dig *subindexes
    end

    def dig?(id : Char) : Chain?
      self[id]?
    end

    def dig?(id : Char, *subindexes)
      if chain = self[id]?
        chain.dig? *subindexes
      end
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

    def n_atoms : Int32
      each_chain.sum &.n_atoms
    end

    def n_chains : Int32
      @chains.size
    end

    def n_residues : Int32
      each_chain.sum &.n_residues
    end

    def to_s(io : ::IO)
      io << "<Structure"
      io << " " << title.inspect unless title.blank?
      io << ": "
      io << n_atoms << " atoms"
      io << ", " << n_residues << " residues" if n_residues > 1
      io << ", "
      io << "non-" unless @lattice
      io << "periodic>"
    end

    def unwrap : self
      raise Spatial::NotPeriodicError.new unless lattice = @lattice
      Spatial::PBC.unwrap self, lattice
      self
    end

    def write(path : Path | String) : Nil
      format = IO::FileFormat.from_ext File.extname(path)
      {% begin %}
        case format
        {% for builder in IO::Builder.subclasses.select(&.annotation(IO::FileType)) %}
          {% format = builder.annotation(IO::FileType)[:format].id.underscore %}
          when .{{format.id}}?
            to_{{format.id}} path
        {% end %}
        else
          raise "No builder associated with file format #{self}"
        end
      {% end %}
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
