require "./pdb/parser"

module Chem::PDB
  extend self

  class ParseException < IO::ParseException; end

  def parse(content : String, **options) : Array(Structure)
    parse ::IO::Memory.new(content), **options
  end

  def parse(io : ::IO, **options) : Array(Structure)
    Parser.new.parse io, **options
  end

  def read(filepath : String, model : Int32) : Structure
    read(filepath, models: {model}).first
  end

  def read(filepath : String, **options) : Array(Structure)
    parse File.read(filepath), **options
  end

  def read_first(filepath : String) : Structure
    read filepath, model: 1
  end
end
