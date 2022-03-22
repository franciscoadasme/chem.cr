module Chem::Topology::Templates
  private TEMPLATES = {} of String => ResidueType

  def self.[](name : String) : ResidueType
    TEMPLATES[name]? || raise Error.new "Unknown residue type #{name}"
  end

  def self.[]?(name : String) : ResidueType?
    TEMPLATES[name]?
  end

  def self.all : Array(ResidueType)
    TEMPLATES.values
  end

  def self.register_type : ResidueType
    ResidueType.build do |builder|
      with builder yield builder
      residue = builder.build
      builder.names.each do |name|
        raise Error.new("#{name} residue type already exists") if TEMPLATES.has_key?(name)
        TEMPLATES[name] = residue
      end
    end
  end
end

require "./templates/detector"
