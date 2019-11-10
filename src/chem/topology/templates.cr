module Chem::Topology::Templates
  extend self

  class Error < Exception; end

  private TEMPLATES = {} of String => ResidueType

  private macro build_method(name, kind = nil)
    def {{name.id}} : ResidueType
      builder = Builder.new ResidueType::Kind::{{(kind || name).id.camelcase}}
      {{yield}}
      with builder yield
      residue = builder.build
      builder.codes.each do |code|
        raise Error.new "Duplicate residue template #{code}" if TEMPLATES.has_key?(code)
        TEMPLATES[code] = residue
      end
      residue
    end
  end

  def [](code : String) : ResidueType
    TEMPLATES[code]? || raise Error.new "Unknown residue template #{code}"
  end

  def []?(code : String) : ResidueType?
    TEMPLATES[code]?
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
