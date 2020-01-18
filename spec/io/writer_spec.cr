require "../spec_helper"

describe Chem::IO::Writer do
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

@[Chem::IO::FileType(format: Document, ext: %w(pdf doc docx rtf))]
class Document::Writer < Chem::IO::Writer(String)
  def write(obj : String) : Nil
    @io << '<' << obj << '>'
  end
end
