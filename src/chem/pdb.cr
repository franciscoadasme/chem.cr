require "./pdb/parser"
require "./pdb/writer"

module Chem::PDB
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
