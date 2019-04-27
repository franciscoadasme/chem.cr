require "../spec_helper"

@[Chem::IO::FileType(format: CAD, ext: [:cad])]
class CAD::Parser < Chem::IO::Parser
  def initialize(@io : IO); end

  def each_structure(&block : Structure ->); end

  def each_structure(indexes : Indexable(Int), &block : Structure ->); end

  def parse
    Chem::Structure.new
  end
end

@[Chem::IO::FileType(format: Image, ext: [:bmp, :jpg, :png, :tiff])]
class Image::Writer < Chem::IO::Writer
  def initialize(@io : IO); end

  def <<(structure : Chem::Structure); end
end

describe Chem::IO::FileFormat do
  describe ".from_ext?" do
    it "returns file format based on file extension" do
      Chem::IO::FileFormat.from_ext?(".bmp").should eq Chem::IO::FileFormat::Image
      Chem::IO::FileFormat.from_ext?(".jpg").should eq Chem::IO::FileFormat::Image
      Chem::IO::FileFormat.from_ext?(".png").should eq Chem::IO::FileFormat::Image
      Chem::IO::FileFormat.from_ext?(".tiff").should eq Chem::IO::FileFormat::Image
      Chem::IO::FileFormat.from_ext?(".cad").should eq Chem::IO::FileFormat::CAD
    end

    it "returns nil for unknown file extension" do
      Chem::IO::FileFormat.from_ext?(".dfgkjh").should be_nil
    end
  end

  describe ".from_ext" do
    it "fails for unknown file extension" do
      expect_raises Exception, "Unknown file extension: .hei" do
        Chem::IO::FileFormat.from_ext ".hei"
      end
    end
  end

  describe "#extnames" do
    it "returns registered file extensions" do
      Chem::IO::FileFormat::Image.extnames.should eq [".bmp", ".jpg", ".png", ".tiff"]
      Chem::IO::FileFormat::CAD.extnames.should eq [".cad"]
    end
  end

  describe "#names" do
    it "returns registered file formats" do
      Chem::IO::FileFormat.names.includes?("CAD").should be_true
      Chem::IO::FileFormat.names.includes?("Image").should be_true
    end
  end

  describe "#parser" do
    it "returns an instance of the registered parser" do
      parser = Chem::IO::FileFormat::CAD.parser IO::Memory.new
      parser.should be_a CAD::Parser
    end

    it "fails when there is no registered parser" do
      expect_raises Exception, "No parser associated with file format Image" do
        Chem::IO::FileFormat::Image.parser IO::Memory.new
      end
    end
  end

  describe "#writer" do
    it "returns an instance of the registered writer" do
      writer = Chem::IO::FileFormat::Image.writer IO::Memory.new
      writer.should be_a Image::Writer
    end

    it "fails when there is no registered writer" do
      expect_raises Exception, "No writer associated with file format CAD" do
        Chem::IO::FileFormat::CAD.writer IO::Memory.new
      end
    end
  end
end
