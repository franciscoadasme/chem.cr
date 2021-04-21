require "./spec_helper"

module Chem
  @[Chem::FileType(ext: %w(cad))]
  module CAD
    class Reader
      include Chem::FormatReader(String)

      def read(type : String.class) : String
        ""
      end
    end
  end

  @[Chem::FileType(ext: %w(bmp jpg png tiff))]
  module Image
    class Writer
      include Chem::FormatWriter(String)

      def write(obj : String) : Nil; end
    end
  end

  @[Chem::FileType(ext: %w(lic), names: %w(SPEC LIC* *KE *any*))]
  module License
    class Writer
      include Chem::FormatWriter(String)

      def write(obj : String) : Nil; end
    end
  end
end

describe Chem::FileFormat do
  describe ".from_ext?" do
    it "returns file format based on file extension" do
      Chem::FileFormat.from_ext?(".bmp").should eq Chem::FileFormat::Image
      Chem::FileFormat.from_ext?(".jpg").should eq Chem::FileFormat::Image
      Chem::FileFormat.from_ext?(".png").should eq Chem::FileFormat::Image
      Chem::FileFormat.from_ext?(".tiff").should eq Chem::FileFormat::Image
      Chem::FileFormat.from_ext?(".TIFF").should eq Chem::FileFormat::Image
      Chem::FileFormat.from_ext?(".cad").should eq Chem::FileFormat::CAD
      Chem::FileFormat.from_ext?(".CAD").should eq Chem::FileFormat::CAD
    end

    it "returns nil for unknown file extension" do
      Chem::FileFormat.from_ext?(".dfgkjh").should be_nil
    end
  end

  describe ".from_ext" do
    it "fails for unknown file extension" do
      expect_raises ArgumentError, "File format not found for .hei" do
        Chem::FileFormat.from_ext ".hei"
      end
    end
  end

  describe ".from_filename" do
    it "fails for unknown filename" do
      expect_raises ArgumentError, "File format not found for foo.bar" do
        Chem::FileFormat.from_filename "foo.bar"
      end
    end
  end

  describe ".from_filename?" do
    it "returns file format based on filename" do
      Chem::FileFormat.from_filename?("img.tiff").should eq Chem::FileFormat::Image
      Chem::FileFormat.from_filename?("spec.cad").should eq Chem::FileFormat::CAD
      Chem::FileFormat.from_filename?("spec").should eq Chem::FileFormat::License
      Chem::FileFormat.from_filename?("license").should eq Chem::FileFormat::License
      Chem::FileFormat.from_filename?("license.key").should eq Chem::FileFormat::License
    end

    it "returns nil for unknown filename" do
      Chem::FileFormat.from_filename?("foo.bar").should be_nil
      Chem::FileFormat.from_filename?("baz").should be_nil
    end
  end

  describe ".from_stem" do
    it "fails for unknown file stem" do
      expect_raises ArgumentError, "File format not found for UNKNOWN" do
        Chem::FileFormat.from_stem "UNKNOWN"
      end
    end
  end

  describe ".from_stem?" do
    it "returns file format based on file stem" do
      %w(SPEC Spec spec LIC LICENSE LICENSE_MIT KE NAM_KE ANY AMANYLOC).each do |stem|
        Chem::FileFormat.from_stem?(stem).should eq Chem::FileFormat::License
      end
    end

    it "returns nil for unknown file stem" do
      %w(Specs LIKENSE NOTLIC KENOT KE_NOT UNKNOWN).each do |stem|
        Chem::FileFormat.from_stem?(stem).should be_nil
      end
    end
  end

  describe "#extnames" do
    it "returns registered file extensions" do
      Chem::FileFormat::Image.extnames.should eq [".bmp", ".jpg", ".png", ".tiff"]
      Chem::FileFormat::CAD.extnames.should eq [".cad"]
    end
  end

  describe "#names" do
    it "returns registered file formats" do
      Chem::FileFormat.names.includes?("CAD").should be_true
      Chem::FileFormat.names.includes?("Image").should be_true
    end
  end
end
