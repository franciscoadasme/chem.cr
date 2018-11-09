module Chem::VASP::Poscar
  class ParseException < IO::ParseException; end

  enum CoordinateSystem
    Cartesian
    Fractional
  end

  def self.parse(io : ::IO) : System
    PullParser.new(io).parse
  end

  def self.read(filepath : String) : System
    parse ::IO::Memory.new File.read(filepath)
  end

  def self.write(filepath : String, system : System)
    File.open(filepath, "w") do |file|
      Writer.new(file).write system
    end
  end

  def self.write(io : ::IO, system : System)
    Writer.new(io).write system
  end
end

require "./poscar/*"
