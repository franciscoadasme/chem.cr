require "../spec_helper"

alias TextParser = Chem::IO::TextParser

describe Chem::IO::TextParser do
  describe "#check" do
    it "checks current character" do
      parser = TextParser.new IO::Memory.new("Lorem ipsum"), 4
      parser.check('L').should be_true
      parser.check('o').should be_false
      parser.read.should eq 'L'
    end

    it "checks current character (block)" do
      parser = TextParser.new IO::Memory.new("Lorem ipsum"), 4
      parser.check(&.letter?).should be_true
      parser.check(&.ascii_lowercase?).should be_false
      parser.read.should eq 'L'
    end

    it "checks current characters" do
      parser = TextParser.new IO::Memory.new("Lorem ipsum"), 6
      parser.check("Lorem").should be_true
      parser.check("orem").should be_false
      parser.read_bytes(6).should eq "Lorem ".to_slice
      parser.check("ipsum ").should be_false
    end

    it "returns false at end of file" do
      parser = TextParser.new IO::Memory.new, 4
      parser.check('A').should be_false
    end
  end

  describe "#each_byte" do
    it "yields each byte" do
      str = "pi = -3.1419"
      bytes = [] of UInt8
      TextParser.new(IO::Memory.new(str), 4).each_byte { |byte| bytes << byte }
      bytes.should eq str.bytes
    end

    it "updates buffer if break" do
      parser = TextParser.new(IO::Memory.new("abcdef 123"), 4)
      parser.each_byte { |byte| break if byte.unsafe_chr.whitespace? }
      parser.read_to_end.should eq " 123"
    end
  end

  describe "#count_bytes_while" do
    it "counts bytes for which block returns true" do
      parser = TextParser.new IO::Memory.new("123 hello world"), 6
      parser.count_bytes_while(&.ascii_number?).should eq 3
      parser.read_bytes(4).should eq "123 ".to_slice
      parser.count_bytes_while(&.chr.ascii_lowercase?).should eq 5
    end

    it "counts bytes starting at offset" do
      parser = TextParser.new IO::Memory.new("123 hello world"), 10
      parser.count_bytes_while(4, &.chr.ascii_lowercase?).should eq 9
    end
  end

  describe "#eof?" do
    it "tells if it is at the end of file" do
      parser = TextParser.new IO::Memory.new("123 hello")
      parser.eof?.should be_false
      parser.skip_to_end
      parser.eof?.should be_true
    end
  end

  describe "#peek" do
    it "returns a char without advancing IO position" do
      io = IO::Memory.new "hello"
      parser = TextParser.new io
      parser.peek.should eq 'h'
      parser.peek.should eq 'h'
      parser.read.should eq 'h'
    end

    it "returns nil at end of file" do
      parser = TextParser.new IO::Memory.new
      parser.peek.should eq nil
      parser.peek.should eq nil
    end
  end

  describe "#peek_byte" do
    it "returns a byte without advancing IO position" do
      io = IO::Memory.new "hello"
      parser = TextParser.new io
      parser.peek_byte.should eq 'h'.ord
      parser.peek_byte.should eq 'h'.ord
      parser.read_byte.should eq 'h'.ord
    end

    it "returns nil at end of file" do
      parser = TextParser.new IO::Memory.new
      parser.peek_byte.should eq nil
      parser.peek_byte.should eq nil
    end
  end

  describe "#peek_bytes" do
    it "returns a slice without advancing IO position" do
      io = IO::Memory.new "hello"
      parser = TextParser.new io
      parser.peek_bytes(3).should eq "hel".to_slice
      parser.peek_bytes(3).should eq "hel".to_slice
      parser.read_bytes(3).should eq "hel".to_slice
      parser.peek_bytes(3).should eq "lo".to_slice
    end

    it "returns an empty slice at end of file" do
      parser = TextParser.new IO::Memory.new
      parser.peek_bytes(10).empty?.should be_true
      parser.peek_bytes(10).empty?.should be_true
    end
  end

  describe "#read" do
    it "raises at end of file" do
      parser = TextParser.new IO::Memory.new("123 hello"), 4
      expect_raises IO::EOFError do
        parser.skip_to_end.read
      end
    end
  end

  describe "#read?" do
    it "reads a byte" do
      parser = TextParser.new IO::Memory.new("123 hello"), 4
      parser.read?.should eq '1'
      parser.read?.should eq '2'
      parser.skip_until(' ')
      parser.read?.should eq ' '
    end

    it "returns nil at end of file" do
      parser = TextParser.new IO::Memory.new("123 hello"), 4
      parser.skip_to_end.read?.should be_nil
    end
  end

  describe "#read_byte" do
    it "raises at end of file" do
      parser = TextParser.new IO::Memory.new("123 hello"), 4
      expect_raises IO::EOFError do
        parser.skip_to_end.read_byte
      end
    end
  end

  describe "#read_byte?" do
    it "reads a byte" do
      parser = TextParser.new IO::Memory.new("123 hello"), 4
      parser.read_byte?.should eq '1'.ord
      parser.read_byte?.should eq '2'.ord
      parser.skip_until(' ')
      parser.read_byte?.should eq ' '.ord
    end

    it "returns nil at end of file" do
      parser = TextParser.new IO::Memory.new("123 hello"), 4
      parser.skip_to_end.read_byte?.should be_nil
    end
  end

  describe "#read_bytes" do
    it "reads N bytes" do
      parser = TextParser.new IO::Memory.new("123 hello"), 4
      parser.read_bytes(2).should eq "12".to_slice
      parser.read_bytes(5).should eq "3 hel".to_slice
      parser.read_bytes(10).should eq "lo".to_slice
      parser.read_bytes(10).empty?.should be_true
    end
  end

  describe "#read_bytes_to_end" do
    it "reads the rest of bytes of the IO" do
      parser = TextParser.new IO::Memory.new("123 hello")
      parser.read_bytes(5)
      parser.read_bytes_to_end.should eq "ello".to_slice
    end
  end

  describe "#read_bytes_until" do
    it "reads bytes before delimiter" do
      io = IO::Memory.new "123 hello"
      parser = TextParser.new io, 2
      parser.read_bytes_until(' ').to_a.should eq "123".bytes
      parser.read_bytes_until('l').to_a.should eq " he".bytes
    end

    it "reads the rest of the IO if delimiter is not found" do
      str = "hello world!"
      parser = TextParser.new IO::Memory.new(str), 4
      parser.read_bytes_until('Z').to_a.should eq str.bytes
    end

    it "reads nothing at end of file" do
      parser = TextParser.new IO::Memory.new("123 hello"), 4
      parser.skip_to_end.read_bytes_until('o').empty?.should be_true
    end
  end

  describe "#read_float" do
    it "raises if float cannot be read" do
      parser = TextParser.new IO::Memory.new("abc")
      expect_raises ParseException do
        parser.read_float
      end
    end
  end

  describe "#read_float?" do
    it "reads a float" do
      parser = TextParser.new IO::Memory.new("hello -123.45 abc"), 10
      parser.skip_until ' '
      parser.read_float?.should eq -123.45
      parser.read_to_end.should eq " abc"
    end

    it "reads a float ending at buffer size" do
      parser = TextParser.new IO::Memory.new("abc -123.4 def"), 10
      parser.read_bytes_until ' '
      parser.read_float?.should eq -123.4
      parser.read_to_end.should eq " def"
    end

    it "reads a float cut at buffer size" do
      parser = TextParser.new IO::Memory.new("abcd  1.2E3 fgh"), 10
      parser.read_bytes_until ' '
      parser.read_float?.should eq 1.2e3
      parser.read_to_end.should eq " fgh"
    end

    it "reads a float with trailing non-whitespace characters" do
      parser = TextParser.new IO::Memory.new("123.456abc"), 10
      parser.read_float?.should be_nil
      parser.read_float?(strict: false).should eq 123.456
    end

    it "reads consecutive floats" do
      parser = TextParser.new IO::Memory.new("1.23 4.56\r\n 7.8\t9.012 \r\n"), 10
      parser.read_float?.should eq 1.23
      parser.read_float?.should eq 4.56
      parser.read_float?.should eq 7.8
      parser.read_float?.should eq 9.012
      parser.read_float?.should be_nil
    end

    it "returns nil for trailing non-whitespace characters" do
      str = "123.456abc"
      parser = TextParser.new IO::Memory.new(str), 8
      parser.read_float?.should be_nil
      parser.read_to_end.should eq str
    end

    it "returns nil if float cannot be read" do
      parser = TextParser.new IO::Memory.new("abc")
      parser.read_float?.should be_nil
    end
  end

  describe "#read_int" do
    it "raises if integer cannot be read" do
      parser = TextParser.new IO::Memory.new("abc")
      expect_raises ParseException do
        parser.read_int
      end
    end
  end

  describe "#read_int?" do
    it "reads an integer" do
      parser = TextParser.new IO::Memory.new("hello 1234 abc"), 10
      parser.skip_until ' '
      parser.read_int?.should eq 1234
      parser.read_to_end.should eq " abc"
    end

    it "reads an integer at the end" do
      parser = TextParser.new IO::Memory.new("abc 1234"), 6
      parser.read_bytes_until ' '
      parser.read_int?.should eq 1234
      parser.read_to_end.should eq ""
    end

    it "reads an integer ending at buffer size" do
      parser = TextParser.new IO::Memory.new("abc -123 def"), 8
      parser.read_bytes_until ' '
      parser.read_int?.should eq -123
      parser.read_to_end.should eq " def"
    end

    it "reads an integer cut at buffer size" do
      parser = TextParser.new IO::Memory.new("abcd  123456 fgh"), 10
      parser.read_bytes_until ' '
      parser.read_int?.should eq 123456
      parser.read_to_end.should eq " fgh"
    end

    it "reads an integer with trailing non-whitespace characters" do
      parser = TextParser.new IO::Memory.new("123.456abc"), 8
      parser.read_int?.should be_nil
      parser.read_int?(strict: false).should eq 123
    end

    it "reads an integer with trailing minus" do
      parser = TextParser.new IO::Memory.new("123-456"), 4
      parser.read_int?.should be_nil
      parser.read_int?(strict: false).should eq 123
    end

    it "reads an integer with leading whitespace cut by buffer" do
      parser = TextParser.new IO::Memory.new("     abcdef  1234  "), 6
      parser.skip_until('a').skip_until(' ')
      parser.read_int?.should eq 1234
    end

    it "reads consecutive integers" do
      parser = TextParser.new IO::Memory.new("123 456\r\n 78\t9012 \r\n"), 8
      parser.read_int?.should eq 123
      parser.read_int?.should eq 456
      parser.read_int?.should eq 78
      parser.read_int?.should eq 9012
      parser.read_int?.should be_nil
    end

    it "returns nil for trailing non-whitespace characters" do
      str = "123.456abc"
      parser = TextParser.new IO::Memory.new(str), 8
      parser.read_int?.should be_nil
      parser.read_to_end.should eq str
    end

    it "returns nil if integer cannot be read" do
      parser = TextParser.new IO::Memory.new("abc")
      parser.read_int?.should be_nil
    end
  end

  describe "#read_line" do
    it "reads a line" do
      parser = TextParser.new IO::Memory.new("Lorem ipsum\ndolor sit amet\r\nabc")
      parser.read_line.should eq "Lorem ipsum"
      parser.read_line.should eq "dolor sit amet"
      parser.read_line.should eq "abc"
    end

    it "fails at eof" do
      expect_raises IO::EOFError do
        TextParser.new(IO::Memory.new).read_line
      end
    end
  end

  describe "#read_to_end" do
    it "reads the rest of the IO" do
      parser = TextParser.new IO::Memory.new("123 hello")
      parser.read_bytes(2)
      parser.read_to_end.should eq "3 hello"
    end
  end

  describe "#read_until" do
    it "reads a string before delimiter" do
      io = IO::Memory.new "123 hello"
      parser = TextParser.new io
      parser.read_until(' ').should eq "123"
      parser.read_until('o').should eq " hell"
    end
  end

  describe "#read_vector" do
    it "raises if a vector cannot be read" do
      io = IO::Memory.new "1.2 abcdef"
      parser = TextParser.new io
      expect_raises ParseException, "Couldn't read a vector" do
        parser.read_vector
      end
    end
  end

  describe "#read_vector?" do
    it "reads a vector" do
      io = IO::Memory.new "1.2 3.4 5.6 7.8 9.0"
      parser = TextParser.new io
      parser.read_vector?.should eq Chem::Spatial::Vector[1.2, 3.4, 5.6]
    end

    it "reads a vector" do
      io = IO::Memory.new "1.2 abcdef"
      parser = TextParser.new io
      parser.read_vector?.should be_nil
    end
  end

  describe "#read_word" do
    it "fails at eof" do
      expect_raises(IO::EOFError) do
        TextParser.new(IO::Memory.new).read_word
      end
    end
  end

  describe "#read_word?" do
    it "reads consecutive non-whitespace characters" do
      str = "The quick\n brown\t\tfox jumps \t\nover the lazy dog"
      parser = TextParser.new IO::Memory.new(str)
      ary = [] of String
      while word = parser.read_word?
        ary << word
      end
      ary.should eq str.split(/\s+/)
    end

    it "returns nil at eof" do
      TextParser.new(IO::Memory.new).read_word?.should be_nil
    end
  end

  describe "#scan" do
    it "reads characters until block returns false" do
      parser = TextParser.new IO::Memory.new("123 abcdef \r\n56.7"), 8
      parser.scan(&.ascii_number?).should eq "123"
      parser.scan(&.ascii_letter?).should eq ""
      parser.scan(&.ascii_whitespace?).should eq " "
      parser.scan(&.ascii_letter?).should eq "abcdef"
      parser.scan { true }.should eq " \r\n56.7"
      parser.scan { true }.empty?.should be_true
    end

    it "reads characters in charset" do
      parser = TextParser.new IO::Memory.new("abc:_:def\n"), 6
      parser.scan('a'..'z').should eq "abc"
      parser.scan(':', '_').should eq ":_:"
      parser.scan(['d', 'e', 'z']).should eq "de"
      parser.scan('0'..'9').should eq ""
      parser.read_to_end.should eq "f\n"
    end
  end

  describe "#scan_bytes" do
    it "reads bytes until block returns false" do
      parser = TextParser.new IO::Memory.new("123 hello\nabcdef \r\n567"), 8
      parser.scan_bytes(&.chr.number?).should eq "123".to_slice
      parser.scan_bytes(&.chr.whitespace?).should eq " ".to_slice
      parser.scan_bytes(&.chr.letter?).should eq "hello".to_slice
      parser.scan_bytes { true }.should eq "\nabcdef \r\n567".to_slice
      parser.scan_bytes { true }.empty?.should be_true
    end
  end

  describe "#skip_bytes" do
    it "reads and discards N bytes" do
      io = IO::Memory.new("123 hello")
      parser = TextParser.new io, 4
      parser.skip_bytes(4).read.should eq 'h'
      parser.skip_bytes(3).read.should eq 'o'
      parser.skip_bytes(10).read?.should be_nil
    end
  end

  describe "#skip_line" do
    it "reads and discards bytes in current line" do
      io = IO::Memory.new("123 hello\nabcdef \r\n567")
      parser = TextParser.new io, 4
      parser.skip_line.read.should eq 'a'
      parser.skip_line.read.should eq '5'
      parser.skip_line.eof?.should be_true
    end
  end

  describe "#skip_to_end" do
    it "reads and discards the rest of the IO" do
      io = IO::Memory.new("123 hello")
      parser = TextParser.new io, 4
      parser.skip_to_end
      io.pos.should eq 9
    end
  end

  describe "#skip_until" do
    it "reads and discards bytes before delimiter" do
      io = IO::Memory.new("123 hello")
      parser = TextParser.new io, 4
      parser.skip_until 'h'
      parser.read_byte.chr.should eq 'h'
    end

    it "reads and discards bytes for which block returns false" do
      parser = TextParser.new IO::Memory.new("  \t  \nhello"), 4
      parser.skip_until(&.chr.letter?)
      parser.read_to_end.should eq "hello"
    end
  end

  describe "#skip_while" do
    it "reads and discards bytes for which block returns true" do
      parser = TextParser.new IO::Memory.new("  \t  \nhello"), 4
      parser.skip_while(&.chr.whitespace?)
      parser.read_to_end.should eq "hello"
    end

    it "reads and discards all bytes if block always returns true" do
      parser = TextParser.new IO::Memory.new("hello"), 2
      parser.skip_while(&.chr.letter?)
      parser.read_to_end.should eq ""
    end

    it "does not skip if block returns false" do
      parser = TextParser.new IO::Memory.new("hello")
      parser.skip_while(&.chr.whitespace?)
      parser.read_to_end.should eq "hello"
    end
  end

  describe "#skip_whitespace" do
    it "reads and discards bytes for which block returns true" do
      parser = TextParser.new IO::Memory.new("  \t  \nhello"), 4
      parser.skip_whitespace
      parser.read_to_end.should eq "hello"
    end
  end

  describe "#skip_word" do
    it "skips a word" do
      io = IO::Memory.new "The quick\n brown\t\tfox jumps \t\r\nover the lazy dog\n"
      parser = TextParser.new io, 4
      parser.skip_word
      parser.read.should eq ' '
      parser.read.should eq 'q'
      parser.skip_word
      parser.read.should eq '\n'
    end
  end
end
