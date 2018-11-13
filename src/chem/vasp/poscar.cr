require "./poscar/*"

module Chem::VASP::Poscar
  extend self

  class ParseException < IO::ParseException; end

  def parse(content : String) : System
    parse ::IO::Memory.new content
  end

  def parse(io : ::IO) : System
    PullParser.new(io).parse
  end

  def read(filepath : String) : System
    parse File.read(filepath)
  end

  def write(filepath : String, system : System)
    File.open(filepath, "w") do |file|
      Writer.new(file).write system
    end
  end

  def write(io : ::IO, system : System)
    Writer.new(io).write system
  end
end
