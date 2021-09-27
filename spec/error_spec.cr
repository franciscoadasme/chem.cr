require "./spec_helper"

describe Chem::ParseException do
  describe "#inspect_with_location" do
    it "shows the location" do
      ex = Chem::ParseException.new(
        message: "Invalid experimental method",
        path: "spec/data/pdb/1crn.pdb",
        line: "EXPDTA    X-RAY DIFFRACTION",
        location: {552, 10, 5}
      )
      ex.inspect_with_location.should eq <<-EOS
        Found a parsing issue in spec/data/pdb/1crn.pdb:

         552 | EXPDTA    X-RAY DIFFRACTION
                         ^^^^^
        Error: Invalid experimental method
        EOS
    end

    it "shows the location without a file" do
      ex = Chem::ParseException.new(
        message: "Invalid experimental method",
        path: nil,
        line: "EXPDTA    X-RAY DIFFRACTION",
        location: {552, 10, 5}
      )
      ex.inspect_with_location.should eq <<-EOS
        Found a parsing issue:

         552 | EXPDTA    X-RAY DIFFRACTION
                         ^^^^^
        Error: Invalid experimental method
        EOS
    end

    it "shows the location at the beginning of line" do
      ex = Chem::ParseException.new(
        message: "Empty content",
        path: "path/to/file",
        line: "abcdef 123456 ABCDEF",
        location: {1025, 0, 0}
      )
      ex.inspect_with_location.should eq <<-EOS
        Found a parsing issue in path/to/file:

         1025 | abcdef 123456 ABCDEF
               ^
        Error: Empty content
        EOS
    end

    it "shows the location at the end of line" do
      ex = Chem::ParseException.new(
        message: "Empty content",
        path: "path/to/file",
        line: "abcdef 123456 ABCDEF",
        location: {6839, 20, 0}
      )
      ex.inspect_with_location.should eq <<-EOS
        Found a parsing issue in path/to/file:

         6839 | abcdef 123456 ABCDEF
                                    ^
        Error: Empty content
        EOS
    end

    it "shows the location of a character" do
      ex = Chem::ParseException.new(
        message: "Invalid character",
        path: "path/to/file",
        line: "abcdef 123456 ABCDEF",
        location: {1952567, 14, 1}
      )
      ex.inspect_with_location.should eq <<-EOS
        Found a parsing issue in path/to/file:

         1952567 | abcdef 123456 ABCDEF
                                 ^
        Error: Invalid character
        EOS
    end
  end
end
