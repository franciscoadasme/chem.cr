require "yaml"

class Chem::ResidueTemplate
  private REGISTRY = {} of String => ResidueTemplate

  @atoms : Array(AtomTemplate)
  @bonds : Array(BondTemplate)

  getter name : String
  getter aliases : Array(String)
  getter type : ResidueType
  getter link_bond : BondTemplate?
  getter description : String?
  getter root_atom : AtomTemplate
  getter code : Char?
  getter symmetric_atom_groups : Array(Array(Tuple(String, String)))?

  def initialize(
    @name : String,
    @code : Char?,
    @type : ResidueType,
    @description : String?,
    atoms : Array(AtomTemplate),
    bonds : Array(BondTemplate),
    @root_atom : AtomTemplate,
    @aliases : Array(String) = [] of String,
    @link_bond : BondTemplate? = nil,
    @symmetric_atom_groups : Array(Array(Tuple(String, String)))? = nil
  )
    @atoms = atoms.dup
    @bonds = bonds.dup
  end

  def self.all_templates : Array(ResidueTemplate)
    REGISTRY.values
  end

  def self.build : self
    builder = ResidueTemplate::Builder.new
    with builder yield builder
    builder.build
  end

  def self.fetch(name : String) : ResidueTemplate
    fetch(name) { raise Error.new("Unknown residue template #{name}") }
  end

  def self.fetch(name : String, & : -> T) : ResidueTemplate | T forall T
    REGISTRY[name]? || yield
  end

  def self.parse(content : String) : Array(self)
    parse IO::Memory.new(content)
  end

  def self.parse(io : IO) : Array(self)
    data = YAML.parse(io)
    if templates = data.dig?("templates").try(&.as_a?)
      templates.map do |hash|
        build do |builder|
          builder.description hash["description"].as_s
          if name = hash["name"]?
            builder.name name.as_s
          else
            builder.names hash["names"].as_a.map(&.as_s)
          end
          hash["code"]?.try { |code| builder.code code.as_s[0] }
          hash["type"]?.try { |type| builder.type ResidueType.parse(type.as_s) }
          hash["structure"]?.try { |spec| builder.structure spec.as_s }
          hash["symmetry"]?.try do |symmetric_atom_groups|
            symmetric_atom_groups.as_a.each do |atom_pairs|
              builder.symmetry atom_pairs.as_a.map { |p| {p[0].as_s, p[1].as_s} }
            end
          end
        end
      end
    else
      raise IO::Error.new("Missing template residues")
    end
  end

  def self.register : ResidueTemplate
    ResidueTemplate.build do |builder|
      with builder yield builder
      residue = builder.build
      ([residue.name] + residue.aliases).each do |name|
        raise Error.new("#{name} residue template already exists") if REGISTRY.has_key?(name)
        REGISTRY[name] = residue
      end
    end
  end

  def [](atom_name : String) : AtomTemplate
    self[atom_name]? || raise Error.new "Unknown atom template #{atom_name}"
  end

  def []?(atom_name : String) : AtomTemplate?
    @atoms.find &.name.==(atom_name)
  end

  def atom_count(*, include_hydrogens : Bool = true)
    size = @atoms.size
    size -= @atoms.count &.element.hydrogen? unless include_hydrogens
    size
  end

  def atom_names : Array(String)
    @atoms.map &.name
  end

  def atoms : Array(AtomTemplate)
    @atoms.dup
  end

  def each_atom_t(&block : AtomTemplate ->)
    @atoms.each &block
  end

  def bonded_atoms(atom_t : AtomTemplate) : Array(AtomTemplate)
    @bonds.select(&.includes?(atom_t)).map &.other(atom_t)
  end

  def bonds : Array(BondTemplate)
    @bonds.dup
  end

  def formal_charge : Int32
    @atoms.each.map(&.formal_charge).sum
  end

  def inspect(io : IO) : Nil
    io << "<ResidueTemplate " << @name
    io << '(' << @code << ')' if @code
    io << ", " << @type.to_s.downcase unless @type.other?
    io << '>'
  end

  def monomer? : Bool
    !link_bond.nil?
  end

  def n_atoms : Int32
    @atoms.size
  end
end
