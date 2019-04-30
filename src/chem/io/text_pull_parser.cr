module Chem::IO::TextPullParser
  INT_REGEX   = /[+-]?\d+/
  FLOAT_REGEX = /[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?/

  delegate scan, scan_until, skip, skip_until, to: @scanner

  def initialize(content : String)
    @scanner = StringScanner.new content
  end

  def parse_exception(msg : String)
    raise IO::ParseException.new msg
  end

  def read_char : Char
    chr = @scanner.string[@scanner.offset]
    @scanner.offset += 1
    chr
  end

  def read_float : Float64
    skip_whitespace
    scan(FLOAT_REGEX).to_s.to_f
  rescue ArgumentError
    parse_exception "Could not read a decimal number"
  end

  def read_int : Int32
    skip_whitespace
    scan(INT_REGEX).to_s.to_i
  rescue ArgumentError
    parse_exception "Could not read an integer number"
  end

  def read_line : String
    scan_until(/\n/).to_s.rstrip
  end

  def skip_line : Nil
    skip_until(/\n/)
  end

  def skip_whitespace : Nil
    skip(/\s*/)
  end
end
