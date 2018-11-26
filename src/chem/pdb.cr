require "./pdb/parser"

module Chem::PDB
  extend self

  class ParseException < IO::ParseException; end

  def parse(content : String, models : Enumerable(Int32)? = nil) : Array(Structure)
    parse ::IO::Memory.new(content), models
  end

  def parse(io : ::IO, models : Enumerable(Int32)? = nil) : Array(Structure)
    Parser.new(io).parse models
  end

  def parse_each(content : String, models : Enumerable(Int32)? = nil, &block : Structure ->)
    parse_each ::IO::Memory.new(content), models, &block
  end

  def parse_each(io : ::IO, models : Enumerable(Int32)? = nil, &block : Structure ->)
    Parser.new(io).parse_each models, &block
  end

  def read(filepath : String, model : Int32) : Structure
    structure = uninitialized Structure
    read_each(filepath, models: {model}) do |st|
      structure = st
    end
    structure
  end

  def read(filepath : String, models : Enumerable(Int32)? = nil) : Array(Structure)
    parse File.read(filepath), models
  end

  def read_each(filepath : String, models : Enumerable(Int32)? = nil, &block : Structure ->)
    parse_each File.read(filepath), models, &block
  end

  def read_first(filepath : String) : Structure
    read filepath, model: 1
  end
end
