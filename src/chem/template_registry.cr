# Stores a map of residue templates (see `ResidueTemplate`).
#
# It behaves as a hash, where residue templates are indexed (registered)
# by the residue names.
#
# A global registry can be accessed via the `TemplateRegistry.default`
# method, which contains the default templates as well as other
# templates that have been globally registered. For instance, the
# topology detection mechanism (see `Topology::Detector`) uses the
# global registry unless a registry is specified.
#
# Local registries could be used to selectively detect a few templates,
# which would speed up the process if existing residues are known
# beforehand, or for another reason.
#
# ### Loading residue templates
#
# Residue templates can be parsed and loaded from a file, IO, or string
# that encodes a registry in the YAML format (see `#parse`).
#
# The following example shows how to create a new registry directly from
# YAML content:
#
# ```
# registry = Chem::TemplateRegistry.from_yaml <<-YAML
#   templates:
#     - description: Phenylalanine
#       names: [PHE, PHY]
#       code: F
#       type: protein
#       link_bond: C-N
#       root: CA
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
# Residue templates can be defined either under the `templates` field or
# at the top-level, and listed as an array of records. A single record
# can also be specified at the top level. The fields in each record are
# passed to the methods of `ResidueTemplate::Builder`, which have the
# same names.
#
# Residue templates can also be loaded into an existing registry using
# either the `#load` or `#parse` methods.
#
# ### Registering a new residue template
#
# Residue templates can also be registered using the DSL provided by
# `ResidueTemplate::Builder` using the `#register` method:
#
# ```
# registry = Chem::TemplateRegistry.new
# res_t = registry.register do
#   description "Phenylalanine"
#   names %w(PHE PHY)
#   code 'F'
#   type :protein
#   link_bond "C-N"
#   root "CA"
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
# registry = Chem::TemplateRegistry.from_yaml <<-YAML
#   templates:
#     - names: [CX1, CX2]
#       description: "Fake residue"
#       spec: CX
#   YAML
# registry["CX1"].description        # => "Fake residue"
# registry["CX1"] == registry["CX2"] # => true
# registry["CX3"]                    # Raises Chem::Error
# registry["CX3"]?                   # => nil
# ```
class Chem::TemplateRegistry
  # Number of residue templates.
  getter size : Int32 = 0

  # Creates a new, empty residue template registry.
  def initialize
    @spec_aliases = {} of String => String
    @table = {} of String => ResidueTemplate
  end

  # Returns the global residue template registry.
  def self.default : self
    # FIXME: load default templates here
    @@default_registry ||= new
  end

  # Returns the residue templates encoded in the given YAML content.
  def self.from_yaml(content : IO | String) : self
    new.parse content
  end

  # Returns the residue templates encoded in the given YAML file.
  def self.load(filepath : Path | String) : self
    new.load filepath
  end

  # Returns the residue template registered under *name*. Raises `Error`
  # if no template exist with the given name.
  def [](name : String) : ResidueTemplate
    self[name]? || raise Error.new("Unknown residue template #{name}")
  end

  # Returns the residue template registered under *name*, or `nil` if no
  # template exist with the given name.
  def []?(name : String) : ResidueTemplate?
    @table[name]?
  end

  # Adds the residue template to the registry. The template is
  # registered under every residue name.
  #
  # Raises `Error` if any of the residue names already exists.
  def <<(res_t : ResidueTemplate) : self
    # FIXME: Implement res_t.names
    ([res_t.name] + res_t.aliases).each do |name|
      raise Error.new("#{name} residue template already exists") if @table.has_key?(name)
      @table[name] = res_t
    end
    @size += 1
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
  def includes?(res_t : ResidueTemplate) : Bool
    # FIXME: Implement res_t.names
    ([res_t.name] + res_t.aliases).any? do |name|
      self[name]? == res_t
    end
  end

  # Parses and registers the residue templates encoded in the given YAML
  # file. See `#parse` for more details.
  def load(filepath : Path | String) : self
    File.open(filepath) do |io|
      load io
    end
  end

  # Parses and registers the residue templates encoded in the given YAML
  # content.
  #
  # Residue templates can be defined either under the `templates` field
  # or at the top-level, and listed as an array of records. A single
  # record can also be specified at the top level. The fields in each
  # record are passed to the methods of `ResidueTemplate::Builder`,
  # which have the same names.
  #
  # The following examples are equivalent:
  #
  # ```yaml
  # templates:
  #   - name: LFG
  #     spec: '[N1H3+]-C2-C3-O4-C5(-C6)=O7'
  #     root: C5
  # ```
  #
  # ```yaml
  # - name: LFG
  #   spec: '[N1H3+]-C2-C3-O4-C5(-C6)=O7'
  #   root: C5
  # ```
  #
  # ```yaml
  # name: LFG
  # spec: '[N1H3+]-C2-C3-O4-C5(-C6)=O7'
  # root: C5
  # ```
  #
  # Validation on template data is handled by
  # `ResidueTemplate::Builder`, which may raise `Error`.
  def parse(io : IO) : self
    data = YAML.parse(io)
    templates = data.dig?("templates").try(&.as_a)
    templates ||= data.as_a? || [data]
    templates.each do |hash|
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
  # template. See `ResidueTemplate::Builder` and `#<<`.
  def register(&) : ResidueTemplate
    builder = ResidueTemplate::Builder.new
    with builder yield builder
    res_t = builder.build
    self << res_t
    res_t
  end

  # Returns a new registry with all the residue templates for which the
  # passed block is falsey.
  def reject(& : ResidueTemplate -> _) : self
    self.select do |res_t|
      !(yield res_t)
    end
  end

  # Returns a new registry with all the residue templates for which the
  # passed block is truthy.
  def select(& : ResidueTemplate -> _) : self
    registry = self.class.new
    @table.each_value do |res_t|
      registry << res_t if !res_t.in?(registry) && yield res_t
    end
    registry
  end

  # Returns an array containing all the residue templates.
  def to_a : Array(ResidueTemplate)
    @table.values.uniq!
  end
end
