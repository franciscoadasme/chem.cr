require "./io"
require "./pdb/parser"
require "./system"

module Chem::PDB
  class ParseException < IO::ParseException; end

  def self.parse(io : ::IO, **options) : Array(System)
    systems = Parser.new.parse io, **options
  end

  def self.read(filepath : String, model : Int32) : System
    read(filepath, models: {model}).first
  end

  def self.read(filepath : String, **options) : Array(System)
    parse ::IO::Memory.new(File.read(filepath)), **options
  end

  def self.read_first(filepath : String) : System
    read filepath, model: 1
  end
end
