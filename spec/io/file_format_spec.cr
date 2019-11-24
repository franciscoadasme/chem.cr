require "../spec_helper"

@[Chem::IO::FileType(format: CAD, ext: [:cad])]
class CAD::Parser < Chem::IO::Parser
  def next; end

  def skip_structure : Nil; end
end

@[Chem::IO::FileType(format: Image, ext: [:bmp, :jpg, :png, :tiff])]
class Image::Writer < Chem::IO::Writer(String)
  def write(obj : String) : Nil; end
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
end
