require "./io"
require "./pdb/parser"
require "./system"

module Chem::PDB
  extend self

  class ParseException < IO::ParseException; end

  def parse(content : String, **options) : Array(System)
    parse ::IO::Memory.new(content), **options
  end

  def parse(io : ::IO, **options) : Array(System)
    systems = Parser.new.parse io, **options
  end

  def read(filepath : String, model : Int32) : System
    read(filepath, models: {model}).first
  end

  def read(filepath : String, **options) : Array(System)
    parse File.read(filepath), **options
  end

  def read_first(filepath : String) : System
    read filepath, model: 1
  end
end
