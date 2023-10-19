require "yaml"

# Stores a map of residue templates (see `Residue`).
#
# It behaves as a hash, where residue templates are indexed (registered)
# by the residue names.
#
# A _global registry_ can be accessed via the `Registry.default` method,
# which contains the default templates as well as other templates that
# have been globally registered. For instance, the topology detection
# mechanism (see `Topology::Detector`) uses the global registry unless a
# registry is specified.
#
# Local registries could be used to selectively detect a few templates,
# which would speed up the process if existing residues are known
# beforehand, or for another reason.
#
# ### Loading residue templates
#
# Residue templates can be parsed and loaded from a file, IO, or string
# that encodes a registry in the YAML format (refer to the [Format
# specification](#format-specification) section).
#
# The following example shows how to create a new registry directly from
# YAML content:
#
# ```
# registry = Chem::Templates::Registry.from_yaml <<-YAML
#   templates:
#     - description: Phenylalanine
#       names: [PHE, PHY]
#       code: F
#       type: protein
#       link_bond: C-N
#       spec: '{backbone}-CB-CG%1=CD1-CE1=CZ-CE2=CD2-%1'
#       symmetry:
#     - [[CD1, CD2], [CE1, CE2]]
#   aliases:
#     backbone: N(-H)-CA(-HA)(-C=O)
#   YAML
# registry.size               # => 1
# registry["PHE"].description # => "Phenylalanine"
# ```
#
# Residue templates can also be loaded into an existing registry using
# either the `#load` or `#parse` methods.
#
# ```
# registry = Chem::Templates::Registry.new.parse <<-YAML
#   ...
#   YAML
# ```
#
# NOTE: A YAML file can be baked into the executable using the
# `read_file` macro at compilation time so it's can be executed
# anywhere. Otherwise, the hardcoded filepath may be inaccessible at
# runtime.
#
# ```
# registry = Chem::Templates::Registry.from_yaml {{read_file("/path/to/yaml")}}
# ```
#
# ### Registering a new residue template
#
# Residue templates can also be registered using the DSL provided by the
# `Builder` type using the `#register` method:
#
# ```
# registry = Chem::Templates::Registry.new
# res_t = registry.register do
#   description "Phenylalanine"
#   names %w(PHE PHY)
#   code 'F'
#   type :protein
#   link_bond "C-N"
#   spec "{backbone}-CB-CG%1=CD1-CE1=CZ-CE2=CD2-%1"
#   symmetry({CD1, CD2}, {CE1, CE2})
# end
# registry["PHE"] == res_t # => true
# ```
#
# ### Retrieving a residue template
#
# Residue templates are indexed by every residue name, so they can be
# accessed using the bracket methods much like a hash.
#
# ```
# registry = Chem::Templates::Registry.from_yaml <<-YAML
#   names: [CX1, CX2]
#   description: "Fake residue"
#   spec: CX
#   YAML
# registry["CX1"].description        # => "Fake residue"
# registry["CX1"] == registry["CX2"] # => true
# registry["CX3"]                    # Raises Chem::Error
# registry["CX3"]?                   # => nil
# ```
#
# ### Format specification
#
# As shown above, residue templates can be encoded in a YAML document.
#
# Residue templates can be defined either under the `templates` field or
# at the top-level, and listed as an array of records. A single record
# can also be specified at the top level.
#
# The following examples are equivalent:
#
# ```yaml
# templates:
#   - name: LFG
#     spec: '[N1H3+]-C2-C3-O4-C5(-C6)=O7'
# ```
#
# ```yaml
# - name: LFG
#   spec: '[N1H3+]-C2-C3-O4-C5(-C6)=O7'
# ```
#
# ```yaml
# name: LFG
# spec: '[N1H3+]-C2-C3-O4-C5(-C6)=O7'
# ```
#
# The records are transformed into `Residue` instances via the `Builder`
# type. Each allowed field correspond to a specific method of the
# builder. The latter dictates the type of data and also handles
# validation.
#
# Aliases for common residue template specifications (spec aliases) can
# be defined as a map under the `aliases` field at the top level:
#
# ```yaml
# ...
# aliases:
#   backbone: 'N(-H)-CA(-HA)(-C=O)'
# ```
#
# Registered aliases are passed down to the `SpecParser` type such that
# they are expanded when parsing the specification of a residue template
# via the bracket syntax, e.g., `'%{backbone}-CB-OH'`.
class Chem::Templates::Registry
  # Number of residue templates.
  getter size : Int32 = 0

  @@default_registry : self?

  # Creates a new, empty residue template registry.
  def initialize
    @spec_aliases = {} of String => String
    @table = {} of String => Residue
    @ter_map = {} of String => Ter
  end

  # Returns the global residue template registry.
  #
  # NOTE: It loads the default templates including proteinogenic
  # aminoacids and their variants (e.g., HIS, HSE, and HSP), and
  # solvents such as water.
  def self.default : self
    @@default_registry ||= new.tap do |registry|
      # bake default templates so it can be loaded from anywhere
      registry.parse {{read_file("#{__DIR__}/../../../data/templates/amino.yaml")}}
      registry.parse {{read_file("#{__DIR__}/../../../data/templates/solvent.yaml")}}
    end
  end

  # Returns the residue templates encoded in the given YAML content.
  def self.from_yaml(content : IO | String) : self
    new.parse content
  end

  # Returns the residue templates encoded in the given YAML file.
  def self.read(filepath : Path | String) : self
    new.load filepath
  end

  # Returns the residue template registered under *name*. Raises `Error`
  # if no template exist with the given name.
  def [](name : String) : Residue
    self[name]? || raise Error.new("Unknown residue template #{name}")
  end

  # Returns the residue template registered under *name*, or `nil` if no
  # template exist with the given name.
  def []?(name : String) : Residue?
    @table[name]?
  end

  # Adds the residue template to the registry. The template is
  # registered under every residue name.
  #
  # Raises `Error` if any of the residue names already exists.
  def <<(res_t : Residue) : self
    res_t.names.each do |name|
      raise Error.new("#{name} residue template already exists") if @table.has_key?(name)
      @table[name] = res_t
    end
    @size += 1
    self
  end

  # Adds the termination template to the registry. The template is
  # registered under every name.
  #
  # Raises `Error` if any of the names already exists.
  def <<(ter_t : Ter) : self
    ter_t.names.each do |name|
      if @ter_map.has_key?(name)
        raise Error.new("#{name} termination template already exists")
      end
      @ter_map[name] = ter_t
    end
    self
  end

  # Registers an aliases to a known residue template. Raises `Error` if
  # *name* is not registered.
  def alias(new_name : String, to existing_name : String) : self
    if res_t = self[existing_name]?
      @table[new_name] = res_t
    else
      raise Error.new("Unknown residue template #{existing_name}")
    end
    self
  end

  # Returns `true` if the registry contains the given residue template,
  # else `false`. Both template's name and content are checked for a
  # match.
  def includes?(res_t : Residue) : Bool
    # FIXME: Implement res_t.names
    res_t.names.any? do |name|
      self[name]? == res_t
    end
  end

  # Loads the residue template(s) encoded in the given YAML or structure
  # file into the registry.
  #
  # If a valid structure file (checked via `Format.from_filename?`) is
  # passed, it's read into a `Structure` instance, and the first residue
  # is transformed into a template by calling `Residue.build`.
  #
  # Otherwise, the content of the YAML file is parsed by calling
  # `Registry#parse`.
  def load(filepath : Path | String) : self
    if Format.from_filename?(filepath) # valid structure file
      structure = Structure.read filepath
      res_t = Residue.build structure.residues[0]
      self << res_t
    else
      File.open(filepath) do |io|
        parse io
      end
    end
  end

  # Parses the residue templates encoded in the given YAML content into
  # the registry. Refer to the [Format
  # specification](#format-specification) section above.
  #
  # Validation on template data is handled by
  # `Builder`, which may raise `Error`.
  def parse(io : IO) : self
    data = YAML.parse(io)
    scoped = false

    # Parse spec aliases first
    data.dig?("aliases").try do |aliases|
      scoped = true
      aliases.as_h.each do |name, spec|
        @spec_aliases[name.as_s] = spec.as_s
      end
    end

    # Parse termination templates
    data.dig?("ters").try do |ters|
      scoped = true
      ters.as_a.each do |hash|
        self << Ter.build do |builder|
          hash["description"]?.try { |any| builder.description any.as_s }
          if name = hash["name"]?
            builder.name name.as_s
          elsif names = hash["names"]
            builder.names names.as_a.map(&.as_s)
          end
          hash["type"]?.try { |type| builder.type ResidueType.parse(type.as_s) }
          hash["spec"]?.try { |spec| builder.spec spec.as_s }
          hash["root"]?.try { |any| builder.root any.as_s }
        end
      end
    end

    # Parse residue templates
    templates = data.dig?("templates").try(&.as_a)
    templates ||= data.as_a? || [data] unless scoped
    templates.try &.each do |hash|
      register do |builder|
        hash["description"]?.try { |any| builder.description any.as_s }
        if name = hash["name"]?
          builder.name name.as_s
        elsif names = hash["names"]
          builder.names names.as_a.map(&.as_s)
        end
        hash["code"]?.try { |code| builder.code code.as_s[0] }
        hash["type"]?.try { |type| builder.type ResidueType.parse(type.as_s) }
        hash["spec"]?.try { |spec| builder.spec spec.as_s }
        hash["root"]?.try { |any| builder.root any.as_s }
        hash["link_bond"]?.try { |any| builder.link_adjacent_by any.as_s }
        hash["symmetry"]?.try do |symmetric_atom_groups|
          symmetric_atom_groups.as_a.each do |atom_pairs|
            builder.symmetry atom_pairs.as_a.map { |p| {p[0].as_s, p[1].as_s} }
          end
        end
      end
    end

    self
  end

  # :ditto:
  def parse(content : String) : self
    parse IO::Memory.new(content)
  end

  # Convenience method that creates and registers a new residue
  # template from a structure. See `Residue.build` and `#<<`.
  def register(structure : Structure) : Residue
    res_t = Residue.build structure.residues[0]
    self << res_t
    res_t
  end

  # Convenience method that creates and registers a new residue
  # template. See `Builder` and `#<<`.
  def register(&) : Residue
    builder = Builder.new @spec_aliases
    with builder yield builder
    res_t = builder.build
    self << res_t
    res_t
  end

  # Returns a new registry with all the residue templates for which the
  # passed block is falsey.
  def reject(& : Residue -> _) : self
    self.select do |res_t|
      !(yield res_t)
    end
  end

  # Returns a new registry with all the residue templates for which the
  # passed block is truthy.
  def select(& : Residue -> _) : self
    registry = self.class.new
    @table.each_value do |res_t|
      registry << res_t if !res_t.in?(registry) && yield res_t
    end
    ters.each do |ter_t|
      registry << ter_t
    end
    registry
  end

  # Registers an alias for a residue template specification.
  #
  # Registered aliases are passed to `SpecParser` such
  # that they are expanded when parsing the specification of a residue
  # template.
  def spec_alias(name : String, spec : String) : self
    @spec_aliases[name] = spec
    self
  end

  # Returns an array containing all the termination templates.
  def ters : Array(Ter)
    @ter_map.values.uniq!
  end

  # Returns an array containing all the residue templates.
  def to_a : Array(Residue)
    @table.values.uniq!
  end
end
