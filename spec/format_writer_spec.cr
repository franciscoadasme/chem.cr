require "./spec_helper"

describe Chem::FormatWriter do
  describe "#to_document" do
    it "returns a string" do
      "foo".to_document.should eq "<foo>"
    end

    it "writes to an IO object" do
      io = IO::Memory.new
      "bar".to_document io
      io.to_s.should eq "<bar>"
    end

    it "writes to a file" do
      path = File.tempname
      "baz".to_document path
      File.read(path).should eq "<baz>"
    end

    it "writes an array" do
      io = IO::Memory.new
      %w(foo bar baz).to_document io
      io.to_s.should eq "<foo><bar><baz>"
    end
  end
end

@[Chem::FileType(ext: %w(pdf doc docx rtf))]
module Chem::Document
  class Writer
    include Chem::FormatWriter(String)

    def write(obj : String) : Nil
      @io << '<' << obj << '>'
    end
  end
end
