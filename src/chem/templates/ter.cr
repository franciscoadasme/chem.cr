class Chem::Templates::Ter
  @atoms : Array(Atom)
  @atom_table : Hash(String, Atom)
  @bonds : Array(Bond)

  getter names : Array(String)
  getter type : ResidueType
  getter description : String?
  getter root : Atom

  def initialize(
    @names : Array(String),
    @type : ResidueType,
    @description : String?,
    @atoms : Array(Atom),
    @bonds : Array(Bond),
    root root_name : String
  )
    raise ArgumentError.new("Empty ter template names") if names.empty?

    @atom_table = @atoms.index_by &.name
    @root = @atom_table.fetch(root_name) { unknown_atom(root_name) }

    if @atom_table.size < atoms.size # atom_table includes unique names only
      name, _ = @atoms.map(&.name).tally.max_by(&.[1])
      raise Error.new("Duplicate atom name #{name.inspect} found in #{self}")
    end
  end

  def self.build : self
    # TODO: use an adhoc builder to avoid setting unneeded things like symmetry
    builder = Builder.new
    with builder yield builder
    res_t = builder.build
    new res_t.names, res_t.type, res_t.description,
      res_t.atoms.to_a, res_t.bonds.to_a, res_t.root.name
  end

  def [](name : String) : Atom
    self[name]? || unknown_atom(name)
  end

  def []?(name : String) : Atom?
    @atom_table[name]?
  end

  def atoms : Array::View(Atom)
    @atoms.view
  end

  def bonds : Array::View(Bond)
    @bonds.view
  end

  # Returns the designated residue name.
  def name : String
    @names.first
  end

  def to_s(io : IO) : Nil
    io << '<' << {{@type.name.split("::").last}} << ' ' << name
    io << ' ' << @type.to_s.downcase unless @type.other?
    io << '>'
  end

  private def unknown_atom(name : String) : Nil
    raise KeyError.new("Atom #{name.inspect} not found in #{self}")
  end
end
