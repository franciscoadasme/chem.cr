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
  end
end

@[Chem::RegisterFormat(ext: %w(.pdf .doc .docx .rtf))]
module Document
  class Writer
    include Chem::FormatWriter(String)

    protected def encode_entry(obj : String) : Nil
      @io << '<' << obj << '>'
    end
  end
end
