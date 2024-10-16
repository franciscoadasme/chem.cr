require "./spec_helper"

describe Chem::PullParser do
  describe "#at" do
    it "raises on cursor out of bounds" do
      pull = parser_for "123 456\n"
      pull.consume_line
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
      until pull.consume_line.eof?; end
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
      pull.consume_line
      pull.at(4, 2).str.should eq "45"
      pull.at(0, 1).str.should eq "1"
      pull.at(3, 10).str.should eq " 456"
      pull.at(2).str.should eq "3"
    end

    it "clamps the cursor at line's end" do
      pull = parser_for "123 456\n"
      pull.consume_line
      pull.at(3, 10)
      pull.str.should eq " 456"
    end

    it "sets the cursor out of bounds silently" do
      pull = parser_for "123 456\n"
      pull.consume_line
      pull.at?(10, 2)
      pull.str?.should be_nil
    end

    it "sets the cursor from a range" do
      pull = parser_for "123 456\n"
      pull.consume_line
      pull.at?(0..2).str.should eq "123"
      pull.at?(1..).str.should eq "23 456"
      pull.at?(..5).str.should eq "123 45"
      pull.at?(..).str.should eq "123 456"
    end
  end

  describe "#bool" do
    it "raises if blank" do
      expect_raises(Chem::ParseException, "Invalid boolean") do
        parser_for("abc   def\n").consume_line.at(3, 3).bool
      end
    end

    it "raises if invalid" do
      expect_raises(Chem::ParseException, "Invalid boolean") do
        parser_for("abc\n").consume_line.consume_token.bool
      end
    end

    it "raises at the beginning of line" do
      expect_raises(Chem::ParseException, "Invalid boolean") do
        parser_for("12345\n").bool
      end
    end

    it "raises at the end of line" do
      expect_raises(Chem::ParseException, "Invalid boolean") do
        pull = parser_for("12345\n")
        pull.consume_line
        until pull.consume_token.eol?; end
        pull.bool
      end
    end

    it "raises with message" do
      expect_raises(Chem::ParseException, %q{Expected a boolean, got "2.3451"}) do
        parser_for("2.3451")
          .consume_line
          .consume_token
          .int("Expected a boolean, got %{token}")
      end
    end

    describe "with default" do
      it "returns it if blank" do
        actual = parser_for("abc   def\n").consume_line.at(3, 3).bool(if_blank: false)
        actual.should be_false
      end

      it "raises if invalid" do
        expect_raises(Chem::ParseException, "Invalid boolean") do
          parser_for("abc\n").consume_line.consume_token.bool(if_blank: true)
        end
      end

      it "returns default at the beginning of line" do
        parser_for("12345\n").bool(if_blank: true).should be_true
      end

      it "returns default at the end of line" do
        pull = parser_for("12345\n").consume_line
        until pull.consume_token.eol?; end
        pull.bool(if_blank: false).should be_false
      end
    end
  end

  describe "#bool?" do
    it_parses "   ", nil, &.bool?
    it_parses "true", true, &.bool?
    it_parses "True", true, &.bool?
    it_parses "TRUE", true, &.bool?
    it_parses "t", true, &.bool?
    it_parses "T", true, &.bool?
    it_parses "false", false, &.bool?
    it_parses "False", false, &.bool?
    it_parses "FALSE", false, &.bool?
    it_parses "f", false, &.bool?
    it_parses "F", false, &.bool?
    it_parses "false   \n", false, &.bool?
    it_parses "foo", nil, &.bool?
    it_parses "truefoo", nil, &.bool?
    it_parses "tr", nil, &.bool?
    it_parses "tru", nil, &.bool?
    it_parses "fa", nil, &.bool?
    it_parses "fal", nil, &.bool?
    it_parses "fals", nil, &.bool?
    it_parses "xtrue", nil, &.bool?

    it "returns nil at the beginning of line" do
      parser_for("true\n").bool?.should be_nil
    end

    it "returns nil at the end of line" do
      pull = parser_for("false\n")
      pull.consume_line
      until pull.consume_token.eol?; end
      pull.bool?.should be_nil
    end
  end

  describe "#char" do
    it "raises on missing char" do
      expect_raises(Chem::ParseException, "Empty token") do
        parser_for("123").char
      end
    end

    it "raises with message" do
      expect_raises(Chem::ParseException, "Letter not found") do
        parser_for("123").char "Letter not found"
      end
    end
  end

  describe "#char?" do
    it "returns the first char of the current token" do
      pull = parser_for "123 456\n789\n"
      pull.consume_line
      pull.consume_token
      pull.char?.should eq '1'
      pull.consume_token
      pull.char?.should eq '4'
    end

    it "returns nil at the beginning of line" do
      parser_for("123").char?.should be_nil
    end

    it "returns nil at end of line" do
      pull = parser_for "123\n456\n789\n"
      pull.consume_line
      until pull.consume_token.eol?; end
      pull.char?.should be_nil
    end

    it "returns nil at end of file" do
      pull = parser_for "123\n456\n789\n"
      until pull.consume_line.eof?; end
      pull.char?.should be_nil
    end
  end

  describe "#consume" do
    it "consumes characters" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.consume(&.alphanumeric?).str?.should eq "123"
      pull.consume(&.alphanumeric?).str?.should be_nil
      pull.consume(&.whitespace?).str?.should eq " "
      pull.consume(&.alphanumeric?).str?.should eq "456"
      pull.consume(&.alphanumeric?).str?.should be_nil
    end

    it "consumes N characters" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.consume(4).str?.should eq "123 "
      pull.consume(2).str?.should eq "45"
      pull.consume(20).str?.should eq "6"
      pull.consume(10).str?.should be_nil
    end
  end

  describe "#consume_until" do
    it "consumes characters until sentinel" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.consume_until(' ').str?.should eq "123"
      pull.consume_until('4').str?.should eq " "
      pull.consume_until('x').str?.should eq "456"
      pull.consume_until('x').str?.should be_nil
    end

    it "consumes characters until block is truthy" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.consume_until(&.whitespace?).str?.should eq "123"
      pull.consume_until(&.in_set?("0-9")).str?.should eq " "
      pull.consume_until(&.whitespace?).str?.should eq "456"
      pull.consume_until(&.alphanumeric?).str?.should be_nil
    end
  end

  describe "#current_line" do
    it "returns current line" do
      pull = parser_for "123\n456\n"
      pull.consume_line
      pull.current_line.should eq "123"
      pull.consume_line
      pull.current_line.should eq "456"
    end

    it "returns nil at the beginning" do
      parser_for("123\n456\n").current_line.should be_nil
    end

    it "returns nil at the beginning" do
      pull = parser_for "123\n456\n"
      until pull.consume_line.eof?; end
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
      pull.consume_line # load first line before iterating
      lines = [] of String
      pull.each_line do |line|
        lines << line
      end
      lines.should eq %w(123 456 789)
    end
  end

  describe "#eol?" do
    it "tells end of line" do
      pull = parser_for "123 456\n789\n"
      pull.eol?.should be_true # no current line
      pull.consume_line
      pull.eol?.should be_false
      pull.consume_token.str?.should eq "123"
      pull.eol?.should be_false
      pull.consume_token.str?.should eq "456"
      pull.eol?.should be_false
      pull.consume_token.str?.should be_nil
      pull.eol?.should be_true
    end
  end

  describe "#eof?" do
    it "returns true at end of file" do
      pull = parser_for "123\n456\n"
      until pull.consume_line.eof?; end
      pull.eof?.should be_true
    end

    it "returns false at the beginning of file" do
      parser_for("123\n456\n").eof?.should be_false
    end

    it "returns false if current line is not nil" do
      pull = parser_for "123\n456\n"
      pull.consume_line # load first line
      pull.eof?.should be_false
    end
  end

  describe "#error" do
    it "raises an exception with location" do
      ex = expect_raises(Chem::ParseException, "Custom message") do
        pull = parser_for "abc def\nABC DEF GHI\n123456789\n"
        pull.consume_line # 1th line
        pull.consume_line # 2nd line
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
        pull.consume_line
        pull.consume_token
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
        pull.consume_line
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
        pull.consume_line
        until pull.consume_token.eol?; end # end of line
        pull.error "Custom message"
      end
      ex.source_file.should be_nil
      ex.line.should eq "abc def"
      ex.location.should eq({1, 7, 0})
    end

    it "raises with placeholders" do
      pull = parser_for "KEY=VALUE"
      pull.consume_line
      pull.at(0, 3)

      expect_raises(Chem::ParseException, %q(Invalid key "KEY")) do
        pull.error "Invalid key %{token}"
      end
      expect_raises(Chem::ParseException, %q(Invalid key "KEY" at 1:1)) do
        pull.error "Invalid key %{token} at %{loc}"
      end
      expect_raises(Chem::ParseException, %q(Invalid key "KEY" at 1:1)) do
        pull.error "Invalid key %{token} at %{loc_with_file}"
      end
    end

    it "raises with placeholders for a file" do
      tempfile = File.tempfile ".txt"
      tempfile << "abc def\nABC DEF GHI\n123456789\n"
      tempfile.rewind

      expect_raises(Chem::ParseException,
        %Q(Found invalid token "DEF" at #{tempfile.path}:2:5)) do
        pull = Chem::PullParser.new tempfile
        pull.consume_line
        pull.consume_line
        pull.consume_token
        pull.consume_token
        pull.error("Found invalid token %{token} at %{loc_with_file}")
      end
    ensure
      tempfile.try &.close
      tempfile.try &.delete
    end
  end

  describe "#expect" do
    it "matches a string" do
      pull = parser_for "abc def"
      pull.consume_line
      pull.consume_token
      pull.expect("abc").str?.should eq "abc"
      pull.consume_token
      pull.expect("def").str?.should eq "def"
    end

    it "matches multiple strings" do
      pull = parser_for "abc def"
      pull.consume_line
      pull.consume_token
      pull.expect({"abc", "def"}).str?.should eq "abc"
      pull.consume_token
      pull.expect({"abc", "def"}).str?.should eq "def"
    end

    it "matches a regexp" do
      pull = parser_for "abc def"
      pull.consume_line
      pull.consume_token
      pull.expect(/[a-z]+/).str?.should eq "abc"
    end

    it "matches a regexp (partial match)" do
      pull = parser_for "123abc\n789\n"
      pull.consume_line
      pull.consume_token
      pull.expect(/[a-z]/).str?.should eq "123abc"
      pull.expect(/[a-z]+/).str?.should eq "123abc"
      pull.expect(/[0-9]+/).str?.should eq "123abc"
    end

    it "raises at end of line" do
      expect_raises(Chem::ParseException, %(Expected "abc", got "")) do
        pull = parser_for ""
        pull.consume_line
        pull.consume_token
        pull.expect("abc")
      end
    end

    it "raises if not match a string" do
      expect_raises(Chem::ParseException, %(Expected "def", got "abc")) do
        pull = parser_for "abc def"
        pull.consume_line
        pull.consume_token
        pull.expect("def")
      end
    end

    it "raises if not match strings" do
      expect_raises(Chem::ParseException, %(Expected "123" or "456", got "abc")) do
        pull = parser_for "abc def"
        pull.consume_line
        pull.consume_token
        pull.expect({"123", "456"})
      end
    end

    it "raises if not match regex" do
      expect_raises(Chem::ParseException, %(Expected "abc" to match /[A-Z]+/)) do
        pull = parser_for "abc def"
        pull.consume_line
        pull.consume_token
        pull.expect(/[A-Z]+/)
      end
    end

    it "raises if not match regex with anchors" do
      expect_raises(Chem::ParseException, %(Expected "123abc" to match /^[0-9]+$/)) do
        pull = parser_for "123abc\n789\n"
        pull.consume_line
        pull.consume_token
        pull.expect(/^[0-9]+$/)
      end
    end

    it "matches a char" do
      pull = parser_for "a b c"
      pull.consume_line
      pull.consume_token
      pull.expect('a').char?.should eq 'a'
      pull.consume_token
      pull.expect('b').char?.should eq 'b'
    end

    it "matches multiple characters" do
      pull = parser_for "a b c d e f"
      pull.consume_line
      pull.consume_token
      pull.expect({'a', 'b'}).char?.should eq 'a'
      pull.consume_token
      pull.expect({'a', 'b'}).char?.should eq 'b'
    end

    it "matches multiple in range" do
      pull = parser_for "a b c d e f"
      pull.consume_line
      pull.consume_token
      pull.expect('a'..'c').char?.should eq 'a'
      pull.consume_token
      pull.expect('a'..'c').char?.should eq 'b'
      pull.consume_token
      pull.expect('a'..'c').char?.should eq 'c'
      pull.expect(..'c').char?.should eq 'c'
      pull.expect('a'..).char?.should eq 'c'
    end

    it "raises if not match char" do
      expect_raises(Chem::ParseException, %(Expected 'b', got 'a')) do
        pull = parser_for "a b c"
        pull.consume_line
        pull.consume_token
        pull.expect('b')
      end
    end

    it "raises if two or more characters" do
      expect_raises(Chem::ParseException, %(Expected 'a', got "abc")) do
        pull = parser_for "abc def"
        pull.consume_line
        pull.consume_token
        pull.expect('a')
      end
    end

    it "raises if not match characters" do
      expect_raises(Chem::ParseException, %(Expected 'a' or 'b', got 'd')) do
        pull = parser_for "d e f"
        pull.consume_line
        pull.consume_token
        pull.expect({'a', 'b'})
      end
    end

    it "raises if not character range" do
      expect_raises(Chem::ParseException, %(Expected 'd' to be within 'a'..'c')) do
        pull = parser_for "d e f"
        pull.consume_line
        pull.consume_token
        pull.expect('a'..'c')
      end
    end
  end

  describe "#float" do
    it "raises if blank" do
      expect_raises(Chem::ParseException, "Invalid real number") do
        pull = parser_for "abc   def"
        pull.consume_line
        pull.at(3, 3).float
      end
    end

    it "raises if invalid" do
      expect_raises(Chem::ParseException, "Invalid real number") do
        pull = parser_for "abc"
        pull.consume_line
        pull.consume_token
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
        pull.consume_line
        until pull.consume_token.eol?; end
        pull.float
      end
    end

    it "raises with message" do
      pull = parser_for "abc def"
      pull.consume_line
      expect_raises(Chem::ParseException, %q{Expected a number, got "def"}) do
        pull.at(4, 3).float("Expected a number, got %{token}")
      end
    end

    describe "with default" do
      it "returns it if blank" do
        pull = parser_for "abc   def"
        pull.consume_line
        pull.at(3, 3).float(if_blank: Math::PI).should eq Math::PI
      end

      it "raises if invalid" do
        expect_raises(Chem::ParseException, "Invalid real number") do
          pull = parser_for "abc"
          pull.consume_line
          pull.consume_token
          pull.float(if_blank: Math::PI)
        end
      end

      it "returns default at the beginning of line" do
        parser_for("123.45").float(if_blank: Math::PI).should eq Math::PI
      end

      it "returns default at the end of line" do
        pull = parser_for("123.45\n")
        pull.consume_line
        until pull.consume_token.eol?; end
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
      pull.consume_line
      until pull.consume_token.eol?; end
      pull.float?.should be_nil
    end
  end

  describe "#int" do
    it "raises if blank" do
      expect_raises(Chem::ParseException, "Invalid integer") do
        pull = parser_for "abc   def\n"
        pull.consume_line
        pull.at(3, 3).int
      end
    end

    it "raises if invalid" do
      expect_raises(Chem::ParseException, "Invalid integer") do
        pull = parser_for "abc\n"
        pull.consume_line
        pull.consume_token
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
        pull.consume_line
        until pull.consume_token.eol?; end
        pull.int
      end
    end

    it "raises with message" do
      pull = parser_for "2.3451"
      pull.consume_line
      pull.consume_token
      expect_raises(Chem::ParseException, %q{Expected an integer, got "2.3451"}) do
        pull.int("Expected an integer, got %{token}")
      end
    end

    describe "with default" do
      it "returns it if blank" do
        pull = parser_for "abc   def\n"
        pull.consume_line
        pull.at(3, 3).int(if_blank: 12345).should eq 12345
      end

      it "raises if invalid" do
        expect_raises(Chem::ParseException, "Invalid integer") do
          pull = parser_for "abc\n"
          pull.consume_line
          pull.consume_token
          pull.int(if_blank: 12345)
        end
      end

      it "returns default at the beginning of line" do
        parser_for("12345\n").int(if_blank: 789).should eq 789
      end

      it "returns default at the end of line" do
        pull = parser_for("12345\n")
        pull.consume_line
        until pull.consume_token.eol?; end
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
      pull.consume_line
      until pull.consume_token.eol?; end
      pull.int?.should be_nil
    end
  end

  describe "#line" do
    it "returns current line" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.line.should eq "123 456"
    end

    it "does not consume" do
      pull = parser_for "123 456\n789\n"
      pull.consume_line
      pull.line.should eq "123 456"
      pull.consume_token
      pull.line.should eq "123 456"
      pull.consume_token
      pull.line.should eq "123 456"
    end

    it "returns nil at end of file" do
      pull = parser_for("123 456\n789\n")
      until pull.consume_line.eof?; end
      pull.line.should be_nil
    end
  end

  describe "#line!" do
    it "returns current line" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.line!.should eq "123 456"
    end

    it "raises at start/end of file" do
      pull = parser_for("123 456\n789\n")
      expect_raises(Chem::ParseException, "Expected a line") { pull.line! }
      until pull.consume_line.eof?; end
      expect_raises(Chem::ParseException, "Expected a line") { pull.line! }
    end
  end

  describe "#consume_line" do
    it "loads and returns the next line in the IO" do
      pull = parser_for("123 456\n789\nABC\tDEF\nabc def ghi\n")
      pull.consume_line.line.should eq "123 456"
      pull.consume_line.line.should eq "789"
      pull.consume_line.line.should eq "ABC\tDEF"
      pull.consume_line.line.should eq "abc def ghi"
    end

    it "resets current token" do
      pull = parser_for("123 456\n789\n")
      pull.str?.should be_nil
      pull.consume_line
      pull.str?.should be_nil
      pull.consume_token
      pull.str?.should eq "123"
      pull.consume_line
      pull.str?.should be_nil
      pull.consume_token
      pull.str?.should eq "789"
    end
  end

  describe "#next_f" do
    it "raises if token is invalid" do
      pull = parser_for("abc 4.56\n789\n")
      pull.consume_line
      expect_raises(Chem::ParseException, "Invalid real number") do
        pull.next_f
      end
    end

    it "raises if line is not set" do
      pull = parser_for("12.3 4.56\n789\n")
      expect_raises(Chem::ParseException, "Invalid real number") do
        pull.next_f
      end
      until pull.consume_line.eof?; end
      expect_raises(Chem::ParseException, "Invalid real number") do
        pull.next_f
      end
    end

    it "raises with message" do
      pull = parser_for "abc def"
      pull.consume_line
      expect_raises(Chem::ParseException, "Expected charge") do
        pull.next_f("Expected charge")
      end
    end
  end

  describe "#next_f?" do
    it "returns the next float" do
      pull = parser_for("12.3 4.56\n789\n")
      pull.consume_line
      pull.next_f.should eq 12.3
      pull.str?.should eq "12.3"
      pull.next_f.should eq 4.56
      pull.str?.should eq "4.56"
    end

    it "returns nil if token is invalid" do
      pull = parser_for("abc 4.56\n789\n")
      pull.consume_line
      pull.next_f?.should be_nil
    end

    it "returns nil if line is not set" do
      pull = parser_for("12.3 4.56\n789\n")
      pull.next_f?.should be_nil
      until pull.consume_line.eof?; end
      pull.next_f?.should be_nil
    end
  end

  describe "#next_i" do
    it "raises if token is invalid" do
      pull = parser_for("abc 4.56\n789\n")
      pull.consume_line
      expect_raises(Chem::ParseException, "Invalid integer") do
        pull.next_i
      end
    end

    it "raises if line is not set" do
      pull = parser_for("123 456\n789\n")
      expect_raises(Chem::ParseException, "Invalid integer") do
        pull.next_i
      end
      until pull.consume_line.eof?; end
      expect_raises(Chem::ParseException, "Invalid integer") do
        pull.next_i
      end
    end

    it "raises with message" do
      pull = parser_for "abc def\n"
      pull.consume_line
      expect_raises(Chem::ParseException, %(Expected count, got "abc")) do
        pull.next_i("Expected count, got %{token}")
      end
    end
  end

  describe "#next_i?" do
    it "returns the next float" do
      pull = parser_for("12 3456\n789\n")
      pull.consume_line
      pull.next_i.should eq 12
      pull.str?.should eq "12"
      pull.next_i.should eq 3456
      pull.str?.should eq "3456"
    end

    it "returns nil if token is invalid" do
      pull = parser_for("abc 4.56\n789\n")
      pull.consume_line
      pull.next_i?.should be_nil
    end

    it "returns nil if line is not set" do
      pull = parser_for("123 456\n789\n")
      pull.next_i?.should be_nil
      until pull.consume_line.eof?; end
      pull.next_i?.should be_nil
    end
  end

  describe "#next_s" do
    it "raises on empty line" do
      pull = parser_for("\n789\n")
      pull.consume_line
      expect_raises(Chem::ParseException, "Empty token") do
        pull.next_s
      end
    end

    it "raises if line is not set" do
      pull = parser_for("123 456\n789\n")
      expect_raises(Chem::ParseException, "Empty token") do
        pull.next_s
      end
      until pull.consume_line.eof?; end
      expect_raises(Chem::ParseException, "Empty token") do
        pull.next_s
      end
    end

    it "raises with message" do
      pull = parser_for "abc def\n"
      pull.consume_line
      while pull.next_s?; end
      expect_raises(Chem::ParseException, "Missing type format") do
        pull.next_s "Missing type format"
      end
    end
  end

  describe "#next_s?" do
    it "returns the next float" do
      pull = parser_for("12 3456\n789\n")
      pull.consume_line
      pull.next_s.should eq "12"
      pull.next_s.should eq "3456"
    end

    it "returns nil on empty line" do
      pull = parser_for("\n789\n")
      pull.consume_line
      pull.next_s?.should be_nil
    end

    it "returns nil if line is not set" do
      pull = parser_for("123 456\n789\n")
      pull.next_s?.should be_nil
      until pull.consume_line.eof?; end
      pull.next_s?.should be_nil
    end
  end

  describe "#consume_token" do
    it "sets the next token" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.consume_token.str?.should eq "123"
      pull.consume_token.str?.should eq "456"
    end

    it "sets an empty token at end of line" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.consume_token.str?.should eq "123"
      pull.consume_token.str?.should eq "456"
      pull.consume_token.str?.should be_nil
    end

    it "sets an empty token at empty line" do
      pull = parser_for("\n789\n")
      pull.consume_line
      pull.consume_token.str?.should be_nil
    end
  end

  describe "#parse?" do
    it "yields the current token and returns the parsed value" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.consume_token
      pull.parse? { |str| str.chars.sum(&.to_i) }.should eq 6
    end

    it "returns nil at beginning of line" do
      parser_for("123 456\n789\n").parse? { Math::PI }.should be_nil
    end

    it "returns nil at end of line" do
      pull = parser_for("123 456\n789\n")
      until pull.consume_token.eol?; end
      pull.parse? { Math::PI }.should be_nil
    end
  end

  describe "#parse" do
    it "yields the current token and returns the parsed value" do
      pull = parser_for("x = baz")
      pull.consume_line
      pull.consume_token
      expect_raises(Chem::ParseException, %q(Invalid option "x")) do
        pull.parse("Invalid option %{token}") do |str|
          %w(foo bar).find &.==(str)
        end
      end
    end
  end

  describe "#parse_if_present" do
    it "parses current token" do
      pull = parser_for(" 0 1")
      pull.consume_line
      pull.at?(2, 2)
      pull.parse_if_present("Invalid option %{token}", &.to_i?).should eq 1
    end

    it "raises if invalid value" do
      pull = parser_for(" 0 a")
      pull.consume_line
      pull.at?(2, 2)
      expect_raises(Chem::ParseException, %q(Could not parse " a" at 1:3)) do
        pull.parse_if_present &.to_i?
      end
    end

    it "raises with message if invalid value" do
      pull = parser_for(" 0 a")
      pull.consume_line
      pull.at?(2, 2)
      expect_raises(Chem::ParseException, %q(Invalid value " a")) do
        pull.parse_if_present "Invalid value %{token}", &.to_i?
      end
    end

    it "returns nil if empty" do
      pull = parser_for(" 0 1")
      pull.consume_line
      pull.at?(4, 2)
      pull.parse_if_present(&.to_i?).should be_nil
    end

    it "returns default value if empty" do
      pull = parser_for(" 0 1")
      pull.consume_line
      pull.at?(4, 2)
      pull.parse_if_present(default: 'K', &.to_i?).should eq 'K'
    end
  end

  describe "#peek" do
    it "returns the next character" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.peek.should eq '1'
      pull.peek.should eq '1'
      pull.consume_token
      pull.peek.should eq ' '
    end

    it "returns nil at end of line" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      until pull.consume_token.eol?; end
      pull.peek.should be_nil
    end
  end

  describe "#rest_of_line" do
    it "returns entire line" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.rest_of_line.should eq "123 456"
      pull.str?.should eq "123 456"
      pull.next_s?.should be_nil
    end

    it "returns rest of line" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.consume_token
      pull.rest_of_line.should eq " 456"
      pull.str?.should eq " 456"
      pull.next_s?.should be_nil
    end

    it "returns empty string at end of line" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      until pull.consume_token.eol?; end
      pull.rest_of_line.should eq ""
    end

    it "returns empty string at end of file" do
      pull = parser_for("123 456\n789\n")
      until pull.consume_line.eof?; end
      pull.rest_of_line.should eq ""
    end
  end

  describe "#skip_whitespace" do
    it "skips whitespace" do
      pull = parser_for("  123 456\n789\n")
      pull.consume_line
      pull.skip_whitespace
      pull.str?.should be_nil # token size is zero
      pull.rest_of_line.should eq "123 456"
    end
  end

  describe "#str" do
    it "raises if current token is not set" do
      expect_raises(Chem::ParseException, "Empty token") do
        parser_for("123 456\n789\n").str
      end
      expect_raises(Chem::ParseException, "Empty token") do
        pull = parser_for("123 456\n789\n")
        pull.consume_line
        pull.str
      end
    end

    it "raises with message" do
      pull = parser_for "abc def\n"
      pull.consume_line
      pull.line
      expect_raises(Chem::ParseException, "Expected element at the end of line") do
        pull.str "Expected element at the end of line"
      end
    end
  end

  describe "#str?" do
    it "returns the current token" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.consume_token
      pull.str?.should eq "123"
      pull.consume_token
      pull.str?.should eq "456"
      pull.at(2, 5).str?.should eq "3 456"
    end

    it "returns nil if current token is not set" do
      pull = parser_for("123 456\n789\n")
      pull.str?.should be_nil
      pull.consume_line
      pull.str?.should be_nil
      pull.consume_token
      pull.consume_line
      pull.str?.should be_nil
    end
  end

  describe "#skip_blank_lines" do
    it "discards blank lines" do
      pull = parser_for("  \t \n \t \r\n\n\n123 456")
      pull.skip_blank_lines
      pull.consume_token.str?.should eq "123"
    end
  end

  describe "#rewind_line" do
    it "sets cursor to the beginning of line" do
      pull = parser_for("123 456 789\n123")
      pull.consume_line
      pull.consume_token
      pull.next_s?.should eq "456"
      pull.rewind_line
      pull.str?.should be_nil
      pull.next_s?.should eq "123"
    end

    it "does nothing if no line is set" do
      pull = parser_for("123 456 789\n123")
      pull.rewind_line
      pull.consume_line
      pull.next_s?.should eq "123"
    end

    it "does nothing at the beginning of line" do
      pull = parser_for("123 456 789\n123")
      pull.consume_line
      pull.rewind_line
      pull.next_s?.should eq "123"
    end
  end

  describe "#parse_next?" do
    it "yields the next token and returns the parsed value" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      pull.consume_token
      pull.parse_next?(&.to_i?).should eq 456
    end

    it "yields the first token at the beginning of line" do
      parser = parser_for("123 456\n789\n")
      parser.consume_line
      parser.parse_next?(&.to_i?).should eq 123
    end

    it "returns nil at end of line" do
      pull = parser_for("123 456\n789\n")
      pull.consume_line
      until pull.consume_token.eol?; end
      pull.parse?(&.to_i?).should be_nil
    end
  end

  describe "#parse_next" do
    it "raises if block returns nil" do
      pull = parser_for("x = baz")
      pull.consume_line
      expect_raises(Chem::ParseException, %q(Invalid option "x")) do
        pull.parse_next("Invalid option %{token}") do |str|
          %w(foo bar).find &.==(str)
        end
      end
    end
  end

  describe "#parse_next_if_present" do
    it "parses next token" do
      pull = parser_for(" 0 1")
      pull.consume_line
      pull.parse_next_if_present("Invalid option %{token}", &.to_i?).should eq 0
    end

    it "raises if invalid value" do
      pull = parser_for(" a 1")
      pull.consume_line
      expect_raises(Chem::ParseException, %q(Could not parse "a" at 1:2)) do
        pull.parse_next_if_present &.to_i?
      end
    end

    it "raises with message if invalid value" do
      pull = parser_for(" a 1")
      pull.consume_line
      expect_raises(Chem::ParseException, %q(Invalid value "a")) do
        pull.parse_next_if_present "Invalid value %{token}", &.to_i?
      end
    end

    it "returns nil if empty" do
      pull = parser_for("\n")
      pull.consume_line
      pull.parse_next_if_present(&.to_i?).should be_nil
    end

    it "returns default value if empty" do
      pull = parser_for("\n")
      pull.consume_line
      pull.parse_next_if_present(default: 'K', &.to_i?).should eq 'K'
    end
  end

  describe "#token" do
    it "returns the current token" do
      pull = parser_for "123 456\n"
      pull.consume_line
      pull.token.should be_nil
      pull.consume_token.token.should eq "123".to_slice
      pull.consume_token.token.should eq "456".to_slice
      pull.consume_token.token.should be_nil
    end
  end
end

private def it_parses(str : String, expected, &block : Chem::PullParser -> _) : Nil
  it "parses #{str}" do
    pull = parser_for str
    pull.consume_line
    pull.at(0, str.bytesize)
    value = block.call(pull)
    value.should eq expected
  end
end

private def parser_for(str : String) : Chem::PullParser
  Chem::PullParser.new IO::Memory.new(str)
end
