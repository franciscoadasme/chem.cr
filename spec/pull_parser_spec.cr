require "./spec_helper"

describe Chem::PullParser do
  describe "#at" do
    it "raises on cursor out of bounds" do
      pull = parser_for "123 456\n"
      pull.next_line
      expect_raises(Chem::ParseException, "Cursor out of current line") do
        pull.at(10, 2)
      end
      expect_raises(Chem::ParseException, "Cursor out of current line") do
        pull.at(10..)
      end
    end

    it "raises at beginning of file" do
      pull = parser_for "123\n456\n"
      expect_raises(Chem::ParseException, "Cursor out of current line") do
        pull.at(0, 2)
      end
      expect_raises(Chem::ParseException, "Cursor out of current line") do
        pull.at(0...2)
      end
    end

    it "raises at end of file" do
      pull = parser_for "123\n456\n"
      while pull.next_line; end
      expect_raises(Chem::ParseException, "Cursor out of current line") do
        pull.at(0, 2)
      end
      expect_raises(Chem::ParseException, "Cursor out of current line") do
        pull.at(0..2)
      end
    end
  end

  describe "#at?" do
    it "sets the cursor" do
      pull = parser_for "123 456\n"
      pull.next_line
      pull.at(4, 2).str.should eq "45"
      pull.at(0, 1).str.should eq "1"
      pull.at(3, 10).str.should eq " 456"
      pull.at(2).str.should eq "3"
    end

    it "clamps the cursor at line's end" do
      pull = parser_for "123 456\n"
      pull.next_line
      pull.at(3, 10)
      pull.str.should eq " 456"
    end

    it "sets the cursor out of bounds silently" do
      pull = parser_for "123 456\n"
      pull.next_line
      pull.at?(10, 2)
      pull.str?.should be_nil
    end

    it "sets the cursor from a range" do
      pull = parser_for "123 456\n"
      pull.next_line
      pull.at?(0..2).str.should eq "123"
      pull.at?(1..).str.should eq "23 456"
      pull.at?(..5).str.should eq "123 45"
      pull.at?(..).str.should eq "123 456"
    end
  end

  describe "#char" do
    it "raises on missing char" do
      expect_raises(Chem::ParseException, "Empty token") do
        parser_for("123").char
      end
    end
  end

  describe "#char?" do
    it "returns the first char of the current token" do
      pull = parser_for "123 456\n789\n"
      pull.next_line
      pull.next_token
      pull.char?.should eq '1'
      pull.next_token
      pull.char?.should eq '4'
    end

    it "returns nil at the beginning of line" do
      parser_for("123").char?.should be_nil
    end

    it "returns nil at end of line" do
      pull = parser_for "123\n456\n789\n"
      pull.next_line
      while pull.next_token; end
      pull.char?.should be_nil
    end

    it "returns nil at end of file" do
      pull = parser_for "123\n456\n789\n"
      while pull.next_line; end
      pull.char?.should be_nil
    end
  end

  describe "#current_line" do
    it "returns current line" do
      pull = parser_for "123\n456\n"
      pull.next_line
      pull.current_line.should eq "123"
      pull.next_line
      pull.current_line.should eq "456"
    end

    it "returns nil at the beginning" do
      parser_for("123\n456\n").current_line.should be_nil
    end

    it "returns nil at the beginning" do
      pull = parser_for "123\n456\n"
      while pull.next_line; end
      pull.current_line.should be_nil
    end
  end

  describe "#each_line" do
    it "yields each line" do
      lines = [] of String
      parser_for("123\n456\n").each_line do |line|
        lines << line
      end
      lines.should eq %w(123 456)
    end

    it "yields current line first" do
      pull = parser_for "123\n456\n789\n"
      pull.next_line # load first line before iterating
      lines = [] of String
      pull.each_line do |line|
        lines << line
      end
      lines.should eq %w(123 456 789)
    end
  end

  describe "#eof?" do
    it "returns true at end of file" do
      pull = parser_for "123\n456\n"
      while pull.next_line; end
      pull.eof?.should be_true
    end

    it "returns false at the beginning of file" do
      parser_for("123\n456\n").eof?.should be_false
    end

    it "returns false if current line is not nil" do
      pull = parser_for "123\n456\n"
      pull.next_line # load first line
      pull.eof?.should be_false
    end
  end

  describe "#error" do
    it "raises an exception with location" do
      ex = expect_raises(Chem::ParseException, "Custom message") do
        pull = parser_for "abc def\nABC DEF GHI\n123456789\n"
        pull.next_line # 1th line
        pull.next_line # 2nd line
        pull.at(3, 3)
        pull.error "Custom message"
      end
      ex.source_file.should be_nil
      ex.line.should eq "ABC DEF GHI"
      ex.location.should eq({2, 3, 3})
    end

    it "raises an exception with path" do
      file = File.tempfile ".txt"
      file << "abc def\nABC DEF GHI\n123456789\n"
      file.rewind
      ex = expect_raises(Chem::ParseException, "Custom message") do
        pull = Chem::PullParser.new file
        pull.next_line
        pull.next_token
        pull.error("Custom message")
      end
      ex.source_file.should eq file.path
      ex.line.should eq "abc def"
      ex.location.should eq({1, 0, 3})
      file.close
    ensure
      file.try &.delete
    end

    it "raises at the beginning of line" do
      ex = expect_raises(Chem::ParseException, "Custom message") do
        pull = parser_for "abc def\nABC DEF GHI\n123456789\n"
        pull.next_line
        # cursor not set (no token)
        pull.error "Custom message"
      end
      ex.source_file.should be_nil
      ex.line.should eq "abc def"
      ex.location.should eq({1, 0, 0})
    end

    it "raises at the end of line" do
      ex = expect_raises(Chem::ParseException, "Custom message") do
        pull = parser_for "abc def\nABC DEF GHI\n123456789\n"
        pull.next_line
        while pull.next_token; end # end of line
        pull.error "Custom message"
      end
      ex.source_file.should be_nil
      ex.line.should eq "abc def"
      ex.location.should eq({1, 7, 0})
    end
  end

  describe "#float" do
    it "raises if blank" do
      expect_raises(Chem::ParseException, "Invalid real number") do
        pull = parser_for "abc   def"
        pull.next_line
        pull.at(3, 3).float
      end
    end

    it "raises if invalid" do
      expect_raises(Chem::ParseException, "Invalid real number") do
        pull = parser_for "abc"
        pull.next_line
        pull.next_token
        pull.float
      end
    end

    it "raises at the beginning of line" do
      expect_raises(Chem::ParseException, "Invalid real number") do
        parser_for("123.45").float
      end
    end

    it "raises at the end of line" do
      expect_raises(Chem::ParseException, "Invalid real number") do
        pull = parser_for("123.45\n")
        pull.next_line
        while pull.next_token; end
        pull.float
      end
    end

    describe "with default" do
      it "returns it if blank" do
        pull = parser_for "abc   def"
        pull.next_line
        pull.at(3, 3).float(if_blank: Math::PI).should eq Math::PI
      end

      it "raises if invalid" do
        expect_raises(Chem::ParseException, "Invalid real number") do
          pull = parser_for "abc"
          pull.next_line
          pull.next_token
          pull.float(if_blank: Math::PI)
        end
      end

      it "returns default at the beginning of line" do
        parser_for("123.45").float(if_blank: Math::PI).should eq Math::PI
      end

      it "returns default at the end of line" do
        pull = parser_for("123.45\n")
        pull.next_line
        while pull.next_token; end
        pull.float(if_blank: Math::PI).should eq Math::PI
      end
    end
  end

  describe "#float?" do
    it_parses "0", 0_f64, &.float?
    it_parses "0.0", 0_f64, &.float?
    it_parses "+0.0", 0_f64, &.float?
    it_parses "-0.0", 0_f64, &.float?
    it_parses "1234.56", 1234.56_f64, &.float?
    it_parses "+1234.56", 1234.56_f64, &.float?
    it_parses "-1234.56", -1234.56_f64, &.float?
    it_parses "foo", nil, &.float?
    it_parses "1234.56foo", nil, &.float?
    it_parses "x1.2", nil, &.float?
    it_parses "12.34   \n", 12.34, &.float?

    it "returns nil at the beginning of line" do
      parser_for("123.45").float?.should be_nil
    end

    it "returns nil at the end of line" do
      pull = parser_for("123.45\n")
      pull.next_line
      while pull.next_token; end
      pull.float?.should be_nil
    end
  end

  describe "#int" do
    it "raises if blank" do
      expect_raises(Chem::ParseException, "Invalid integer") do
        pull = parser_for "abc   def\n"
        pull.next_line
        pull.at(3, 3).int
      end
    end

    it "raises if invalid" do
      expect_raises(Chem::ParseException, "Invalid integer") do
        pull = parser_for "abc\n"
        pull.next_line
        pull.next_token
        pull.int
      end
    end

    it "raises at the beginning of line" do
      expect_raises(Chem::ParseException, "Invalid integer") do
        parser_for("12345\n").int
      end
    end

    it "raises at the end of line" do
      expect_raises(Chem::ParseException, "Invalid integer") do
        pull = parser_for("12345\n")
        pull.next_line
        while pull.next_token; end
        pull.int
      end
    end

    describe "with default" do
      it "returns it if blank" do
        pull = parser_for "abc   def\n"
        pull.next_line
        pull.at(3, 3).int(if_blank: 12345).should eq 12345
      end

      it "raises if invalid" do
        expect_raises(Chem::ParseException, "Invalid integer") do
          pull = parser_for "abc\n"
          pull.next_line
          pull.next_token
          pull.int(if_blank: 12345)
        end
      end

      it "returns default at the beginning of line" do
        parser_for("12345\n").int(if_blank: 789).should eq 789
      end

      it "returns default at the end of line" do
        pull = parser_for("12345\n")
        pull.next_line
        while pull.next_token; end
        pull.int(if_blank: 789).should eq 789
      end
    end
  end

  describe "#int?" do
    it_parses "   ", nil, &.int?
    it_parses "0", 0_i32, &.int?
    it_parses "+0", 0_i32, &.int?
    it_parses "-0", 0_i32, &.int?
    it_parses "123456", 123456_i32, &.int?
    it_parses "+123456", 123456_i32, &.int?
    it_parses "-123456", -123456_i32, &.int?
    it_parses "0000123456", 123456_i32, &.int?
    it_parses "+0000123456", 123456_i32, &.int?
    it_parses "-0000123456", -123456_i32, &.int?
    it_parses "foo", nil, &.int?
    it_parses "123456foo", nil, &.int?
    it_parses "x123456", nil, &.int?
    it_parses "8   \n", 8, &.int?

    it "returns nil at the beginning of line" do
      parser_for("123456\n").int?.should be_nil
    end

    it "returns nil at the end of line" do
      pull = parser_for("123456\n")
      pull.next_line
      while pull.next_token; end
      pull.int?.should be_nil
    end
  end

  describe "#line" do
    it "returns current line" do
      pull = parser_for("123 456\n789\n")
      pull.next_line
      pull.line.should eq "123 456"
    end

    it "returns rest of current line" do
      pull = parser_for("123 456\n789\n")
      pull.next_line
      pull.next_token
      pull.next_token
      pull.line.should eq "456"
    end

    it "returns an empty string at end of line" do
      pull = parser_for("123 456\n789\n")
      pull.next_line
      while pull.next_token; end
      pull.line.should eq ""
    end

    it "raises at end of file" do
      pull = parser_for("123 456\n789\n")
      while pull.next_line; end
      expect_raises(Chem::ParseException, "End of file") do
        pull.line
      end
    end
  end

  describe "#next_line" do
    it "loads and returns the next line in the IO" do
      pull = parser_for("123 456\n789\nABC\tDEF\nabc def ghi\n")
      pull.next_line.should eq "123 456"
      pull.next_line.should eq "789"
      pull.next_line.should eq "ABC\tDEF"
      pull.next_line.should eq "abc def ghi"
    end

    it "resets current token" do
      pull = parser_for("123 456\n789\n")
      pull.str?.should be_nil
      pull.next_line
      pull.str?.should be_nil
      pull.next_token
      pull.str?.should eq "123"
      pull.next_line
      pull.str?.should be_nil
      pull.next_token
      pull.str?.should eq "789"
    end

    it "returns nil at end of file" do
      pull = parser_for("123 456\n789\n")
      pull.next_line.should eq "123 456"
      pull.next_line.should eq "789"
      pull.next_line.should be_nil
    end
  end

  describe "#next_f" do
    it "raises if token is invalid" do
      pull = parser_for("abc 4.56\n789\n")
      pull.next_line
      expect_raises(Chem::ParseException, "Invalid real number") do
        pull.next_f
      end
    end

    it "raises if line is not set" do
      pull = parser_for("12.3 4.56\n789\n")
      expect_raises(Chem::ParseException, "Invalid real number") do
        pull.next_f
      end
      while pull.next_line; end
      expect_raises(Chem::ParseException, "Invalid real number") do
        pull.next_f
      end
    end
  end

  describe "#next_f?" do
    it "returns the next float" do
      pull = parser_for("12.3 4.56\n789\n")
      pull.next_line
      pull.next_f.should eq 12.3
      pull.str?.should eq "12.3"
      pull.next_f.should eq 4.56
      pull.str?.should eq "4.56"
    end

    it "returns nil if token is invalid" do
      pull = parser_for("abc 4.56\n789\n")
      pull.next_line
      pull.next_f?.should be_nil
    end

    it "returns nil if line is not set" do
      pull = parser_for("12.3 4.56\n789\n")
      pull.next_f?.should be_nil
      while pull.next_line; end
      pull.next_f?.should be_nil
    end
  end

  describe "#next_i" do
    it "raises if token is invalid" do
      pull = parser_for("abc 4.56\n789\n")
      pull.next_line
      expect_raises(Chem::ParseException, "Invalid integer") do
        pull.next_i
      end
    end

    it "raises if line is not set" do
      pull = parser_for("123 456\n789\n")
      expect_raises(Chem::ParseException, "Invalid integer") do
        pull.next_i
      end
      while pull.next_line; end
      expect_raises(Chem::ParseException, "Invalid integer") do
        pull.next_i
      end
    end
  end

  describe "#next_i?" do
    it "returns the next float" do
      pull = parser_for("12 3456\n789\n")
      pull.next_line
      pull.next_i.should eq 12
      pull.str?.should eq "12"
      pull.next_i.should eq 3456
      pull.str?.should eq "3456"
    end

    it "returns nil if token is invalid" do
      pull = parser_for("abc 4.56\n789\n")
      pull.next_line
      pull.next_i?.should be_nil
    end

    it "returns nil if line is not set" do
      pull = parser_for("123 456\n789\n")
      pull.next_i?.should be_nil
      while pull.next_line; end
      pull.next_i?.should be_nil
    end
  end

  describe "#next_s" do
    it "raises on empty line" do
      pull = parser_for("\n789\n")
      pull.next_line
      expect_raises(Chem::ParseException, "Empty token") do
        pull.next_s
      end
    end

    it "raises if line is not set" do
      pull = parser_for("123 456\n789\n")
      expect_raises(Chem::ParseException, "Empty token") do
        pull.next_s
      end
      while pull.next_line; end
      expect_raises(Chem::ParseException, "Empty token") do
        pull.next_s
      end
    end
  end

  describe "#next_s?" do
    it "returns the next float" do
      pull = parser_for("12 3456\n789\n")
      pull.next_line
      pull.next_s.should eq "12"
      pull.next_s.should eq "3456"
    end

    it "returns nil on empty line" do
      pull = parser_for("\n789\n")
      pull.next_line
      pull.next_s?.should be_nil
    end

    it "returns nil if line is not set" do
      pull = parser_for("123 456\n789\n")
      pull.next_s?.should be_nil
      while pull.next_line; end
      pull.next_s?.should be_nil
    end
  end

  describe "#next_token" do
    it "reads and returns the bytes of the next token" do
      pull = parser_for("123 456\n789\n")
      pull.next_line
      pull.next_token.should eq "123".to_slice
      pull.next_token.should eq "456".to_slice
    end

    it "returns nil at end of line" do
      pull = parser_for("123 456\n789\n")
      pull.next_line
      pull.next_token.should eq "123".to_slice
      pull.next_token.should eq "456".to_slice
      pull.next_token.should be_nil
    end

    it "returns nil at empty line" do
      pull = parser_for("\n789\n")
      pull.next_line
      pull.next_token.should be_nil
    end
  end

  describe "#parse" do
    it "yields the current token and returns the parsed value" do
      pull = parser_for("123 456\n789\n")
      pull.next_line
      pull.next_token
      pull.parse { |bytes| bytes.sum(&.-('0'.ord)) }.should eq 6
    end

    it "returns nil at beginning of line" do
      parser_for("123 456\n789\n").parse { Math::PI }.should be_nil
    end

    it "returns nil at end of line" do
      pull = parser_for("123 456\n789\n")
      while pull.next_token; end
      pull.parse { Math::PI }.should be_nil
    end
  end

  describe "#str" do
    it "raises if current token is not set" do
      expect_raises(Chem::ParseException, "Empty token") do
        parser_for("123 456\n789\n").str
      end
      expect_raises(Chem::ParseException, "Empty token") do
        pull = parser_for("123 456\n789\n")
        pull.next_line
        pull.str
      end
    end
  end

  describe "#str?" do
    it "returns the current token" do
      pull = parser_for("123 456\n789\n")
      pull.next_line
      pull.next_token
      pull.str?.should eq "123"
      pull.next_token
      pull.str?.should eq "456"
      pull.at(2, 5).str?.should eq "3 456"
    end

    it "returns nil if current token is not set" do
      pull = parser_for("123 456\n789\n")
      pull.str?.should be_nil
      pull.next_line
      pull.str?.should be_nil
      pull.next_token
      pull.next_line
      pull.str?.should be_nil
    end
  end

  describe "#skip_blank_lines" do
    it "discards blank lines" do
      pull = parser_for("  \t \n \t \r\n\n\n123 456")
      pull.skip_blank_lines
      pull.next_token
      pull.str?.should eq "123"
    end
  end
end

private def it_parses(str : String, expected, &block : Chem::PullParser -> _) : Nil
  it "parses #{str}" do
    pull = parser_for str
    pull.next_line
    pull.at(0, str.bytesize)
    value = block.call(pull)
    value.should eq expected
  end
end

private def parser_for(str : String) : Chem::PullParser
  Chem::PullParser.new IO::Memory.new(str)
end
