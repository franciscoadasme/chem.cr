require "./incar/*"

module Chem::VASP::Incar
  class ParseException < IO::ParseException; end

  def self.parse(filepath : String)
    File.open(filepath) { |file| parse file }
  end

  def self.parse(io : IO)
    PullParser.new(io).parse
  end
end
