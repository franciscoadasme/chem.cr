require "./poscar/*"

module Chem::VASP::Poscar
  extend self

  class ParseException < IO::ParseException; end

  def parse(content : String) : Structure
    parse ::IO::Memory.new content
  end

  def parse(io : ::IO) : Structure
    PullParser.new(io).parse
  end

  def read(filepath : String) : Structure
    parse File.read(filepath)
  end

  def write(filepath : String, structure : Structure)
    File.open(filepath, "w") do |file|
      Writer.new(file).write structure
    end
  end

  def write(io : ::IO, structure : Structure)
    Writer.new(io).write structure
  end
end
