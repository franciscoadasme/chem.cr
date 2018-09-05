module Chem::Topology::Templates
  class Error < Exception; end

  private TEMPLATES = {} of String => Residue

  def self.[](code : String) : Residue
    TEMPLATES[code] || raise Error.new "unknown residue #{code}"
  end

  def self.[]?(code : String) : Residue?
    TEMPLATES[code]?
  end

  def self.aminoacid : Nil
    builder = Builder.new
    builder.backbone
    with builder yield
    residue = builder.build
    if TEMPLATES.has_key?(residue.code)
      raise Error.new "duplicate residue code #{residue.code}"
    end
    TEMPLATES[residue.code] = residue
  end

  def self.residue : Nil
    builder = Builder.new
    with builder yield
    residue = builder.build
    if TEMPLATES.has_key?(residue.code)
      raise Error.new "duplicate residue code #{residue.code}"
    end
    TEMPLATES[residue.code] = residue
  end
end

require "./templates/builder"
require "./templates/template"
