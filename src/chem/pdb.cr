require "./pdb/*"

module Chem::PDB
  def self.build(**options) : String
    String.build do |io|
      build(io, **options) do |poscar|
        yield poscar
      end
    end
  end

  def self.build(io : ::IO, **options) : Nil
    builder = Builder.new io, **options
    builder.document do
      yield builder
    end
  end

  def self.read(filepath : String) : Array(Structure)
    Parser.new(File.read(filepath)).parse_all
  end

  def self.read(filepath : String, model : Int) : Structure
    Parser.new(File.read(filepath)).parse model
  end

  def self.read(filepath : String, models : Array(Int)) : Array(Structure)
    Parser.new(File.read(filepath)).parse models
  end
end
