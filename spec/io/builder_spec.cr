require "../spec_helper"

describe Chem::IO::Builder do
  describe "#to_document" do
    structure = Chem::Structure.build { }

    it "returns a string" do
      structure.to_document.should eq "document"
    end

    it "writes to an IO object" do
      io = IO::Memory.new
      structure.to_document io
      io.to_s.should eq "document"
    end

    it "writes to a file" do
      path = File.tempname
      structure.to_document path
      File.read(path).should eq "document"
    end
  end
end

@[Chem::IO::FileType(format: Document, ext: [:pdf, :doc, :docx, :rtf])]
class Document::Builder < Chem::IO::Builder
  def initialize(@io : IO)
  end
end

class Chem::Structure
  def to_document(document : Document::Builder) : Nil
    document.string "document"
  end
end
