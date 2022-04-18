module Chem
  class Structure
    include AtomCollection
    include ChainCollection
    include ResidueCollection

    getter biases = [] of Chem::Bias
    property experiment : Structure::Experiment?
    property cell : Spatial::Parallelepiped?
    getter source_file : Path?
    property title : String = ""
    getter topology : Topology

    # TODO: remove this delegates... directly use the topology class
    delegate :[], :[]?,
      delete,
      dig, dig?,
      atoms, chains, residues,
      to: @topology

    def initialize(@topology : Topology = Topology.new, source_file : Path | String | Nil = nil)
      source_file = Path.new(source_file) if source_file.is_a?(String)
      @source_file = source_file.try(&.expand)
      @topology.structure = self
    end

    def self.build(*args, **options, &) : self
      builder = Structure::Builder.new *args, **options
      with builder yield builder
      builder.build
    end

    def clear : self
      @topology.clear
      self
    end

    # Returns a deep copy of `self`, that is, every chain/residue/atom is copied.
    #
    # Unlike array-like classes in the language, `#dup` (shallow copy) is not possible.
    #
    # ```
    # structure = Structure.new "/path/to/file.pdb"
    # other = structure.clone
    # other == structure     # => true
    # other.same?(structure) # => false
    #
    # structure.dig('A', 23, "OG").partial_charge         # => 0.0
    # other.dig('A', 23, "OG").partial_charge             # => 0.0
    # structure.dig('A', 23, "OG").partial_charge = 0.635 # => 0.635
    # other.dig('A', 23, "OG").partial_charge             # => 0.0
    # ```
    def clone : self
      structure = Structure.new @topology.clone, @source_file
      structure.biases.concat @biases
      structure.experiment = @experiment
      structure.cell = @cell
      structure.title = @title
      structure
    end

    def coords : Spatial::CoordinatesProxy
      Spatial::CoordinatesProxy.new self, @cell
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

    def each_atom(& : Atom ->)
      each_chain do |chain|
        chain.each_atom do |atom|
          yield atom
        end
      end
    end

    def each_chain : Iterator(Chain)
      @topology.each_chain
    end

    def each_chain(& : Chain ->)
      @topology.each_chain do |chain|
        yield chain
      end
    end

    def each_residue : Iterator(Residue)
      Iterator.chain each_chain.map(&.each_residue).to_a
    end

    def each_residue(& : Residue ->)
      each_chain do |chain|
        chain.each_residue do |residue|
          yield residue
        end
      end
    end

    def n_atoms : Int32
      @topology.n_atoms
    end

    def n_chains : Int32
      @topology.n_chains
    end

    def n_residues : Int32
      @topology.n_residues
    end

    def periodic? : Bool
      !!@cell
    end

    def to_s(io : IO)
      io << "<Structure"
      io << " " << title.inspect unless title.blank?
      io << ": "
      io << n_atoms << " atoms"
      io << ", " << n_residues << " residues" if n_residues > 1
      io << ", "
      io << "non-" unless @cell
      io << "periodic>"
    end
  end
end
