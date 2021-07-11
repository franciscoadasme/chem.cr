require "./spec_helper"

@[Chem::RegisterFormat(format: CAD, ext: %w(.cad))]
class CAD::Reader < Chem::FormatReader(String)
  def read_entry : String
    "foo"
  end
end

@[Chem::RegisterFormat(format: Image, ext: %w(.bmp .jpg .png .tiff))]
class Image::Writer < Chem::FormatWriter(String)
  def write(obj : String) : Nil; end
end

@[Chem::RegisterFormat(format: License, ext: %w(.lic), names: %w(SPEC LIC* *KE *any*))]
class License::Writer < Chem::FormatWriter(String)
  def write(obj : String) : Nil; end
end

describe Chem::Format do
  describe ".from_ext?" do
    it "returns file format based on file extension" do
      Chem::Format.from_ext?(".bmp").should eq Chem::Format::Image
      Chem::Format.from_ext?(".jpg").should eq Chem::Format::Image
      Chem::Format.from_ext?(".png").should eq Chem::Format::Image
      Chem::Format.from_ext?(".tiff").should eq Chem::Format::Image
      Chem::Format.from_ext?(".TIFF").should eq Chem::Format::Image
      Chem::Format.from_ext?(".cad").should eq Chem::Format::CAD
      Chem::Format.from_ext?(".CAD").should eq Chem::Format::CAD
    end

    it "returns nil for unknown file extension" do
      Chem::Format.from_ext?(".dfgkjh").should be_nil
    end
  end

  describe ".from_ext" do
    it "fails for unknown file extension" do
      expect_raises ArgumentError, "File format not found for .hei" do
        Chem::Format.from_ext ".hei"
      end
    end
  end

  describe ".from_filename" do
    it "fails for unknown filename" do
      expect_raises ArgumentError, "File format not found for foo.bar" do
        Chem::Format.from_filename "foo.bar"
      end
    end
  end

  describe ".from_filename?" do
    it "returns file format based on filename" do
      Chem::Format.from_filename?("img.tiff").should eq Chem::Format::Image
      Chem::Format.from_filename?("spec.cad").should eq Chem::Format::CAD
      Chem::Format.from_filename?("spec").should eq Chem::Format::License
      Chem::Format.from_filename?("license").should eq Chem::Format::License
      Chem::Format.from_filename?("license.key").should eq Chem::Format::License
    end

    it "returns nil for unknown filename" do
      Chem::Format.from_filename?("foo.bar").should be_nil
      Chem::Format.from_filename?("baz").should be_nil
    end
  end

  describe ".from_stem" do
    it "fails for unknown file stem" do
      expect_raises ArgumentError, "File format not found for UNKNOWN" do
        Chem::Format.from_stem "UNKNOWN"
      end
    end
  end

  describe ".from_stem?" do
    it "returns file format based on file stem" do
      %w(SPEC Spec spec LIC LICENSE LICENSE_MIT KE NAM_KE ANY AMANYLOC).each do |stem|
        Chem::Format.from_stem?(stem).should eq Chem::Format::License
      end
    end

    it "returns nil for unknown file stem" do
      %w(Specs LIKENSE NOTLIC KENOT KE_NOT UNKNOWN).each do |stem|
        Chem::Format.from_stem?(stem).should be_nil
      end
    end
  end

  describe "#extnames" do
    it "returns registered file extensions" do
      Chem::Format::Image.extnames.should eq [".bmp", ".jpg", ".png", ".tiff"]
      Chem::Format::CAD.extnames.should eq [".cad"]
    end
  end

  describe "#names" do
    it "returns registered file formats" do
      Chem::Format.names.includes?("CAD").should be_true
      Chem::Format.names.includes?("Image").should be_true
    end
  end
end
