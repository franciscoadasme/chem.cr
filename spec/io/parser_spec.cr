require "../spec_helper"

describe Chem::IO::ParserWithLocation do
  describe "#parse_exception" do
    it "raises an exception with location" do
      parser = ParserWithLocationTest.new "Lorem ipsum\n123 321 66\n23 123 21\n foo bar"
      parser.read 26
      parser.read 3
      ex = expect_raises(ParseException) { parser.parse_exception "Custom error" }
      ex.message.should eq "Custom error"
      ex.loc.should_not be_nil
      loc = ex.loc.not_nil!
      loc.source_file.should be_nil
      loc.line_number.should eq 3
      loc.column_number.should eq 4
      loc.size.should eq 3
      ex.to_s_with_location.should eq <<-EOS
        In line 3:4:

         1 | Lorem ipsum
         2 | 123 321 66
         3 | 23 123 21
                ^~~
        Error: Custom error
        EOS
    end

    it "raises an exception at the end of line" do
      parser = ParserWithLocationTest.new "Lorem ipsum\n123 321 66\n23 123 21"
      parser.read 22
      parser.read 1
      ex = expect_raises(ParseException) { parser.parse_exception "Custom error" }
      ex.message.should eq "Custom error"
      ex.loc.should_not be_nil
      loc = ex.loc.not_nil!
      loc.source_file.should be_nil
      loc.line_number.should eq 2
      loc.column_number.should eq 11
      loc.size.should eq 1
      ex.to_s_with_location.should eq <<-EOS
        In line 2:11:

         1 | Lorem ipsum
         2 | 123 321 66
                       ^
        Error: Custom error
        EOS
    end
  end
end

describe Chem::IO::PullParser do
  describe "#check" do
    it "checks current character" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.check('L').should be_true
      parser.check('o').should be_false
      parser.read.should eq 'L'
    end

    it "checks current character (block)" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.check(&.letter?).should be_true
      parser.check(&.ascii_lowercase?).should be_false
      parser.read.should eq 'L'
    end

    it "checks current characters" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.check("Lorem").should be_true
      parser.check("orem").should be_false
      parser.read(6).should eq "Lorem "
      parser.check("ipsum ").should be_false
    end

    it "returns false at end of file" do
      parser = PullParserTest.new "Lorem ipsum\n"
      parser.read_line
      parser.read?.should be_nil
      parser.check("Lorem").should be_false
    end
  end

  describe "#check_in_set" do
    it "checks current character is in charset" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.check_in_set("A-Z").should be_true
      parser.check_in_set("a-z0-9").should be_false
      parser.read.should eq 'L'
    end
  end

  describe "#fail" do
    it "fails with message containing line and column" do
      parser = PullParserTest.new "Lorem ipsum\ndolor\nsit amet,\nconsectetur adipiscing."
      parser.read 22
      expect_raises ParseException, "Invalid character" do
        parser.parse_exception "Invalid character"
      end
    end
  end

  describe "#peek" do
    it "reads a character without advancing position" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.peek.should eq 'L'
      parser.peek.should eq 'L'
    end

    it "reads N characters without advancing position" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.peek(5).should eq "Lorem"
      parser.peek(5).should eq "Lorem"
    end

    it "fails at end of file" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.read_line
      expect_raises IO::EOFError do
        parser.peek
      end
    end
  end

  describe "#peek?" do
    it "reads a character without advancing position" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.peek?.should eq 'L'
      parser.peek?.should eq 'L'
    end

    it "reads N characters without advancing position" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.peek?(5).should eq "Lorem"
      parser.peek?(5).should eq "Lorem"
    end

    it "returns nil at end of file" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.read_line
      parser.peek?.should be_nil
    end
  end

  describe "#peek_line" do
    it "reads a line without modifying io position" do
      parser = PullParserTest.new("Lorem ipsum\ndolor sit amet")
      parser.peek_line.should eq "Lorem ipsum"
      parser.peek_line.should eq "Lorem ipsum"
    end

    it "fails at end of line" do
      parser = PullParserTest.new ""
      expect_raises IO::EOFError do
        parser.peek_line
      end
    end
  end

  describe "#peek_line?" do
    it "returns nil at end of file" do
      parser = PullParserTest.new("Lorem ipsum\n")
      parser.read_line
      parser.peek_line?.should be_nil
    end
  end

  describe "#prev_char" do
    it "returns the previous char" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.read 10
      parser.prev_char.should eq 'u'
    end

    it "fails at the beginning of io" do
      parser = PullParserTest.new "Lorem ipsum"
      expect_raises ParseException, "Couldn't read previous character" do
        parser.prev_char
      end
    end
  end

  describe "#read" do
    it "reads one character" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.read.should eq 'L'
      parser.char_span.should eq 1
      parser.read.should eq 'o'
      parser.char_span.should eq 1
    end

    it "reads N characters" do
      parser = PullParserTest.new "Lorem ipsum\n0 1 2 3 4"
      parser.read(5).should eq "Lorem"
      parser.char_span.should eq 5
      parser.read(10).should eq " ipsum\n0 1"
      parser.char_span.should eq 10
    end

    it "fails at eof" do
      expect_raises(IO::EOFError) { PullParserTest.new("").read }
      expect_raises(IO::EOFError) { PullParserTest.new("").read 10 }
    end
  end

  describe "#read?" do
    it "returns nil at eof" do
      PullParserTest.new("").read?.should be_nil
      PullParserTest.new("").read?(10).should be_nil
    end
  end

  describe "#read_float" do
    it "reads a float" do
      PullParserTest.new("125.35").read_float.should eq 125.35
      PullParserTest.new("+125.35").read_float.should eq 125.35
      PullParserTest.new("-125.35").read_float.should eq -125.35

      parser = PullParserTest.new "1.2.3.4"
      parser.read_float.should eq 1.2
      parser.char_span.should eq 3
    end

    it "reads a float from N characters" do
      PullParserTest.new("-125.35").read_float(6).should eq -125.3
    end

    it "reads a float with leading spaces" do
      PullParserTest.new("  -125.35").read_float.should eq -125.35
    end

    it "reads a float in scientific notation" do
      PullParserTest.new("1e-1").read_float.should eq 0.1
      PullParserTest.new("1E-1").read_float.should eq 0.1
      PullParserTest.new("-1.25e4").read_float.should eq -12_500

      parser = PullParserTest.new("-1.25e-3_")
      parser.read_float.should eq -0.00125
      parser.char_span.should eq 8
    end

    it "fails with an invalid float" do
      expect_raises ParseException, "Couldn't read a decimal number" do
        PullParserTest.new("abcd").read_float
      end
    end
  end

  describe "#read_int" do
    it "reads an integer" do
      parser = PullParserTest.new "12574 "
      parser.read_int.should eq 12574
      parser.char_span.should eq 5
    end

    it "reads an integer from N characters" do
      PullParserTest.new("12574").read_int(4).should eq 1257
    end

    it "fails with an invalid integer" do
      expect_raises ParseException, "Couldn't read a number" do
        PullParserTest.new("abcd").read_int 4
      end
    end
  end

  describe "#read_in_set" do
    it "reads a character" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.read_in_set("A-Z").should eq 'L'
    end

    it "does not read a character if not in charset" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.read_in_set("0-9").should be_nil
      parser.read.should eq 'L'
    end

    it "returns nil at end of file" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.read_line
      parser.read_in_set("a-z").should be_nil
    end
  end

  describe "#read_line" do
    it "reads a line" do
      parser = PullParserTest.new("Lorem ipsum\ndolor sit amet")
      parser.read_line.should eq "Lorem ipsum"
      parser.char_span.should eq 12
    end

    it "fails at eof" do
      expect_raises IO::EOFError do
        PullParserTest.new("").read_line
      end
    end
  end

  describe "#rewind" do
    it "moves the io backwards while the previous character passes a predicate" do
      parser = PullParserTest.new "Lorem ipsum dolor sit amet"
      parser.read 10
      parser.rewind(&.letter?).read.should eq 'i'
    end

    it "does not fail at the beginning of io" do
      parser = PullParserTest.new "Lorem ipsum dolor sit amet"
      parser.rewind(&.letter?).read.should eq 'L'
    end
  end

  describe "#scan" do
    it "reads characters that match a pattern" do
      parser = PullParserTest.new "Lorem ipsum!\ndolor sit amet"
      parser.scan(/\w/).should eq "Lorem"
      parser.char_span.should eq 5
    end

    it "returns an empty string if the next character does not match the pattern" do
      parser = PullParserTest.new "Lorem ipsum dolor sit amet"
      parser.scan(/\d/).should eq ""
      parser.char_span.should eq 0
    end

    it "reads characters that pass a predicate" do
      parser = PullParserTest.new "Lorem ipsum dolor sit amet"
      parser.scan { |char| char.letter? }.should eq "Lorem"
      parser.char_span.should eq 5
    end

    it "returns an empty string if the next character does not pass the predicate" do
      parser = PullParserTest.new "Lorem ipsum dolor sit amet"
      parser.scan { |char| char.number? }.should eq ""
      parser.char_span.should eq 0
    end

    it "reads characters into a IO object" do
      io = IO::Memory.new
      parser = PullParserTest.new "Lorem ipsum dolor sit amet"
      parser.scan io, &.letter?
      parser.char_span.should eq 5
      io.to_s.should eq "Lorem"
    end

    it "reads characters that match a pattern into a IO object" do
      io = IO::Memory.new
      parser = PullParserTest.new "Lorem ipsum dolor sit amet"
      parser.scan io, /[A-Z]/
      parser.char_span.should eq 1
      io.to_s.should eq "L"
    end
  end

  describe "#scan_in_set" do
    it "reads characters in set" do
      parser = PullParserTest.new "Lorem ipsum dolor sit amet"
      parser.scan_in_set("A-Z").should eq "L"
      parser.scan_in_set("A-Z").should eq ""
      parser.scan_in_set("a-z").should eq "orem"
    end
  end

  describe "#scan_delimited" do
    it "reads character groups delimited by whitespace" do
      parser = PullParserTest.new "I you he she it we they. 231345"
      groups = parser.scan_delimited &.letter?
      groups.should eq ["I", "you", "he", "she", "it", "we", "they"]
    end

    it "reads character groups delimited by a character" do
      parser = PullParserTest.new "a|b||cd|ef  \n1|2|34"
      groups = parser.scan_delimited '|', &.letter?
      groups.should eq ["a", "b", "", "cd", "ef"]
    end

    it "reads character groups delimited by characters" do
      parser = PullParserTest.new "a|b__cd|ef__\n1|2|34"
      groups = parser.scan_delimited_by_set "|_", &.letter?
      groups.should eq ["a", "b", "cd", "ef"]
    end
  end

  describe "#scan_until" do
    it "reads characters that does not match a pattern" do
      parser = PullParserTest.new "Lorem ipsum!, dolor sit amet"
      parser.scan_until(/[,!]/).should eq "Lorem ipsum"
      parser.read.should eq '!'
    end
  end

  describe "#skip" do
    it "skips a character" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.skip
      parser.char_span.should eq 1
      parser.read.should eq 'o'
    end

    it "skips N characters" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.skip 10
      parser.char_span.should eq 10
      parser.read.should eq 'm'
    end

    it "skips occurrences of a character" do
      parser = PullParserTest.new "---abcd"
      parser.skip '-'
      parser.char_span.should eq 3
      parser.read.should eq 'a'
    end

    it "skips N occurrences of a character at most" do
      parser = PullParserTest.new "---abcd"
      parser.skip '-', limit: 2
      parser.char_span.should eq 2
      parser.peek(2).should eq "-a"
      parser.skip '-', limit: 10
      parser.char_span.should eq 1
      parser.read.should eq 'a'
    end

    it "skips characters that pass a predicate" do
      parser = PullParserTest.new "1342,!, ,Lorem ipsum"
      parser.skip { |char| !char.letter? }
      parser.char_span.should eq 9
      parser.read.should eq 'L'
    end

    it "skips N characters that pass the predicate at most" do
      parser = PullParserTest.new "Lorem ipsum"
      parser.skip limit: 4, &.letter?
      parser.char_span.should eq 4
      parser.peek(2).should eq "m "

      parser.skip limit: 10, &.letter?
      parser.char_span.should eq 1
      parser.read.should eq ' '
    end

    it "skips characters that match a pattern" do
      parser = PullParserTest.new "Lorem ipsum!\ndolor sit amet"
      parser.skip /[\w\s]/
      parser.char_span.should eq 11
      parser.read.should eq '!'
    end

    it "does not fail at end of file" do
      parser = PullParserTest.new "Lorem ipsum\n"
      parser.read_line
      parser.skip(&.letter?)
    end
  end

  describe "#skip_in_set" do
    it "skips characters in set" do
      parser = PullParserTest.new "Lorem123"
      parser.skip_in_set "A-Za-z"
      parser.read?.should eq '1'
    end
  end

  describe "#skip_line" do
    it "skips line" do
      parser = PullParserTest.new "Lorem ipsum\ndolor sit amet"
      parser.skip_line
      parser.char_span.should eq 12
      parser.read.should eq 'd'
    end

    it "does not fail at end of file" do
      parser = PullParserTest.new "Lorem ipsum\n"
      parser.read_line
      parser.skip_line
    end
  end

  describe "#skip_spaces" do
    it "skips spaces and tabs only" do
      parser = PullParserTest.new "  \t\nLorem ipsum"
      parser.skip_spaces.read.should eq '\n'
    end
  end

  describe "#skip_whitespace" do
    it "skips whitespace" do
      parser = PullParserTest.new "  \nLorem ipsum"
      parser.skip_whitespace.read.should eq 'L'
    end
  end
end

describe Chem::IO::AsciiParser do
  describe "#peek" do
    it "returns a char without advacing IO position" do
      io = IO::Memory.new "The quick brown fox jumps over the lazy dog"
      parser = CustomAsciiParser.new io
      parser.peek.should eq 'T'
      parser.peek.should eq 'T'
      parser.read.should eq 'T'
    end

    it "returns nil at eof" do
      parser = CustomAsciiParser.new IO::Memory.new
      parser.peek.should eq nil
      parser.peek.should eq nil
    end
  end

  describe "#read_float" do
    it "reads consecutive floats" do
      io = make_io do |io|
        1000.times do |i|
          io.printf "%16.8f", (i + 1) / 5
          io << '\n' if i % 5 == 0
        end
      end

      parser = CustomAsciiParser.new io
      ary = [] of Float64
      1000.times { ary << parser.read_float }
      ary[0].should eq 0.2
      ary[342].should eq 68.6
      ary[999].should eq 200
    end
  end

  describe "#read_word" do
    it "fails at eof" do
      expect_raises(IO::EOFError) do
        CustomAsciiParser.new(IO::Memory.new).read_word
      end
    end
  end

  describe "#read_word?" do
    it "reads consecutive non-whitespace characters" do
      io = IO::Memory.new "The quick\n brown\t\tfox jumps \t\nover the lazy dog\n"
      parser = CustomAsciiParser.new io
      ary = [] of String
      while word = parser.read_word?
        ary << word
      end
      ary.should eq %w(The quick brown fox jumps over the lazy dog)
    end

    it "returns nil at eof" do
      CustomAsciiParser.new(IO::Memory.new).read_word?.should be_nil
    end
  end

  describe "#read_vector" do
    it "reads a vector" do
      io = IO::Memory.new "1.000 2.000 3.00"
      parser = CustomAsciiParser.new io
      parser.read_vector.should eq V[1, 2, 3]
    end
  end

  describe "#skip_line" do
    it "skips a line" do
      io = IO::Memory.new "The quick\n brown\t\tfox jumps \t\r\nover the lazy dog\n"
      parser = CustomAsciiParser.new io
      parser.skip_line
      parser.read.should eq ' '
      parser.read.should eq 'b'
      parser.skip_line
      parser.read_word.should eq "over"
    end
  end

  describe "#skip_lines" do
    it "skips lines" do
      io = IO::Memory.new "The quick\n brown\t\tfox jumps \t\r\nover the lazy dog\n"
      parser = CustomAsciiParser.new io
      parser.skip_lines 2
      parser.read_word.should eq "over"
    end
  end

  describe "#skip_word" do
    it "skips a word" do
      io = IO::Memory.new "The quick\n brown\t\tfox jumps \t\r\nover the lazy dog\n"
      parser = CustomAsciiParser.new io
      parser.skip_word
      parser.read.should eq ' '
      parser.read.should eq 'q'
      parser.skip_word
      parser.read.should eq '\n'
    end
  end

  describe "#skip_words" do
    it "skips words" do
      io = IO::Memory.new "The quick\n brown\t\tfox jumps \t\r\nover the lazy dog\n"
      parser = CustomAsciiParser.new io
      parser.skip_words 5
      parser.read_word.should eq "over"
    end
  end
end

class ParserWithLocationTest
  include Chem::IO::ParserWithLocation

  def initialize(content : String)
    @io = IO::Memory.new content
  end

  def read(count : Int = 1) : String
    read { @io.read_string count }
  end
end

class PullParserTest
  include Chem::IO::PullParser

  def initialize(content : String)
    @io = IO::Memory.new(content)
  end

  def char_span : Int32 | Int64
    @io.pos - @prev_pos
  end
end

class CustomAsciiParser
  include Chem::IO::AsciiParser

  def initialize(@io : IO)
  end

  def parse_exception(msg : String) : Nil
    raise msg
  end
end

def make_io(& : IO ->) : IO
  io = IO::Memory.new
  yield io
  io.rewind
  io
end
