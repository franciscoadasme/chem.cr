require "./spec_helper"

@[Chem::RegisterFormat(ext: %w(.cad))]
module CAD
  def self.read(io : IO | Path | String) : String
    "foo"
  end
end

@[Chem::RegisterFormat(ext: %w(.bmp .jpg .png .tiff))]
module Image
  def self.write(io : IO, obj : String) : Nil; end
end

@[Chem::RegisterFormat(ext: %w(.lic), names: %w(SPEC LIC* *KE *ANY*))]
module License
  def self.write(io : IO, obj : String) : Nil; end
end

@[Chem::RegisterFormat]
module MultiString
  def self.write(io : IO, obj : String) : Nil; end
end

describe Chem do
  describe ".guess_format?" do
    it "returns format module based on filename" do
      Chem.guess_format?("file.bmp").should eq Image
      Chem.guess_format?("file.jpg").should eq Image
      Chem.guess_format?("file.png").should eq Image
      Chem.guess_format?("file.tiff").should eq Image
      Chem.guess_format?("file.TIFF").should eq Image
      Chem.guess_format?("file.cad").should eq CAD
      Chem.guess_format?("file.CAD").should eq CAD
      Chem.guess_format?("file.lic").should eq License

      Chem.guess_format?("img.tiff").should eq Image
      Chem.guess_format?("spec.cad").should eq CAD
      Chem.guess_format?("SPEC").should eq License
      Chem.guess_format?("LICENSE").should eq License
      Chem.guess_format?("LICENSE.key").should eq License

      %w(SPEC LIC LICENSE LICENSE_MIT KE NAM_KE ANY AMANYLOC).each do |stem|
        Chem.guess_format?(stem).should eq License
      end
    end

    it "returns nil for unknown file" do
      Chem.guess_format?("file.dfgkjh").should be_nil
      Chem.guess_format?("foo.bar").should be_nil
      Chem.guess_format?("baz").should be_nil
      Chem.guess_format?("UNKNOWN").should be_nil
      %w(Spec spec Specs LIKENSE NOTLIC KENOT KE_NOT UNKNOWN).each do |stem|
        Chem.guess_format?(stem).should be_nil
      end
    end
  end

  describe ".guess_format" do
    it "fails for unknown file" do
      expect_raises ArgumentError, "File format not found for file.hei" do
        Chem.guess_format "file.hei"
      end
      expect_raises ArgumentError, "File format not found for foo.bar" do
        Chem.guess_format "foo.bar"
      end
      expect_raises ArgumentError, "File format not found for UNKNOWN" do
        Chem.guess_format "UNKNOWN"
      end
    end
  end
end
