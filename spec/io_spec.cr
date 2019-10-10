require "./spec_helper"

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
  end
end

describe Chem::IO::ParseException do
  describe "#to_s_with_location" do
    it "returns error message" do
      ex = ParseException.new "Custom error"
      ex.to_s_with_location.should eq "Custom error"
    end

    it "returns error message with location" do
      loc = Chem::IO::Location.new line_number: 131, column_number: 41, size: 1
      ex = ParseException.new "Custom error", loc
      ex.to_s_with_location.should eq "In line 131:41: Custom error"
    end

    it "returns error message with location and error indicator" do
      ex = ParseException.new "Invalid flag (expected either T or F)",
        Chem::IO::Location.new(line_number: 131, column_number: 41, size: 1),
        lines: ["<Atoms>", "10", " C  0.01231530  0.24573951  0.71057249  A  B  C"]
      ex.to_s_with_location.should eq <<-EOS
        In line 131:41:

         129 | <Atoms>
         130 | 10
         131 |  C  0.01231530  0.24573951  0.71057249  A  B  C
                                                       ^
        Error: Invalid flag (expected either T or F)
        EOS
    end

    it "returns error message with location and error indicator (size > 0)" do
      ex = ParseException.new "Could not read a decimal number",
        Chem::IO::Location.new(line_number: 28, column_number: 20, size: 8),
        lines: ["   1  2   23.1235  23.1235e   23.1235    1.00   C"]
      ex.to_s_with_location.should eq <<-EOS
        In line 28:20:

         28 |    1  2   23.1235  23.1235e   23.1235    1.00   C
                                 ^~~~~~~~
        Error: Could not read a decimal number
        EOS
    end

    it "returns error message with file location" do
      loc = Chem::IO::Location.new(
        source_file: "/home/foo/bar/baz.cr",
        line_number: 131,
        column_number: 41,
        size: 1)
      ex = ParseException.new "Custom error", loc
      ex.to_s.should eq "Custom error"
      ex.to_s_with_location.should eq "In /home/foo/bar/baz.cr:131:41: Custom error"
    end

    it "returns error message with file location and error indicator" do
      ex = ParseException.new(
        "Invalid coordinate system (expected either Cartesian or Direct)",
        Chem::IO::Location.new(
          source_file: "/home/foo/Desktop/bar.poscar",
          line_number: 7,
          column_number: 1,
          size: 10),
        lines: ["Fractional"])
      ex.to_s_with_location.should eq <<-EOS
        In /home/foo/Desktop/bar.poscar:7:1:

         7 | Fractional
             ^~~~~~~~~~
        Error: Invalid coordinate system (expected either Cartesian or Direct)
        EOS
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
