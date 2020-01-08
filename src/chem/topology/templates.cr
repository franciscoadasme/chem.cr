module Chem::Topology::Templates
  extend self

  class Error < Exception; end

  private TEMPLATES = {} of String => ResidueType

  private macro build_method(name, kind = nil)
    def {{name.id}} : ResidueType
      ResidueType.build(Residue::Kind::{{(kind || name).id.camelcase}}) do |builder|
        {{yield}}
        with builder yield builder
        residue = builder.build
        builder.names.each do |name|
          raise Error.new "Duplicate residue template #{name}" if TEMPLATES.has_key?(name)
          TEMPLATES[name] = residue
        end
      end
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
