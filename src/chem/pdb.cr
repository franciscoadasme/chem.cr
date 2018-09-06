require "./io"
require "./pdb/parser"
require "./system"

module Chem::PDB
  class ParseException < IO::ParseException; end

  def self.parse(filepath : String) : System
    parse ::IO::Memory.new File.read(filepath)
  end

  def self.parse(io : ::IO) : System
    Parser.new(io).parse
  end
end
