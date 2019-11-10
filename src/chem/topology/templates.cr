module Chem::Topology::Templates
  extend self

  class Error < Exception; end

  private TEMPLATES = {} of String => ResidueType

  private macro build_method(name, kind = nil)
    def {{name.id}} : ResidueType
      builder = Builder.new Residue::Kind::{{(kind || name).id.camelcase}}
      {{yield}}
      with builder yield
      residue = builder.build
      builder.names.each do |name|
        raise Error.new "Duplicate residue template #{name}" if TEMPLATES.has_key?(name)
        TEMPLATES[name] = residue
      end
      residue
    end
  end

  def [](name : String) : ResidueType
    TEMPLATES[name]? || raise Error.new "Unknown residue template #{name}"
  end

  def []?(name : String) : ResidueType?
    TEMPLATES[name]?
  end

  def all : Array(ResidueType)
    TEMPLATES.values
  end

  build_method aminoacid, kind: protein
  build_method residue, kind: other
  build_method solvent
end

require "./templates/builder"
require "./templates/detector"
require "./templates/entities"
