module Chem::Topology::Templates
  extend self

  class Error < Exception; end

  private TEMPLATES = {} of String => Residue

  private macro build_method(name, kind = nil)
    def {{name.id}} : Residue
      builder = Builder.new Residue::Kind::{{(kind || name).id.camelcase}}
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

  def [](code : String) : Residue
    TEMPLATES[code]? || raise Error.new "Unknown residue template #{code}"
  end

  def []?(code : String) : Residue?
    TEMPLATES[code]?
  end

  build_method aminoacid, kind: protein
  build_method residue, kind: other
  build_method solvent
end

require "./templates/builder"
require "./templates/entities"
