require "./spec_helper"

@[Chem::RegisterFormat(ext: %w(.cad))]
module CAD
  class Reader
    include Chem::FormatReader(String)
    include Chem::FormatReader::MultiEntry(String)

    protected def decode_entry : String
      "foo"
    end

    def skip_entry : Nil; end
  end
end

@[Chem::RegisterFormat(ext: %w(.bmp .jpg .png .tiff))]
module Image
  class Writer
    include Chem::FormatWriter(String)

    protected def encode_entry(obj : String) : Nil; end
  end
end

@[Chem::RegisterFormat(ext: %w(.lic), names: %w(SPEC LIC* *KE *any*))]
module License
  class Writer
    include Chem::FormatWriter(String)

    protected def encode_entry(obj : String) : Nil; end
  end
end

@[Chem::RegisterFormat]
module MultiString
  class Writer
    include Chem::FormatWriter(String)
    include Chem::FormatWriter::MultiEntry(String)

    protected def encode_entry(obj : String) : Nil; end
  end
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

  describe "#encodes?" do
    it "tells if the format encodes a given type" do
      Chem::Format::XYZ.encodes?(Chem::Structure).should be_true
      Chem::Format::XYZ.encodes?(Chem::AtomCollection).should be_true
      Chem::Format::Poscar.encodes?(Chem::Structure).should be_true
      Chem::Format::Poscar.encodes?(Chem::AtomCollection).should be_false
      Chem::Format::XYZ.encodes?(Int32).should be_false
    end

    it "tells if the format encodes an array of a given type" do
      Chem::Format::XYZ.encodes?(Array(Chem::Structure)).should be_true
      Chem::Format::XYZ.encodes?(Array(Chem::AtomCollection)).should be_true
      Chem::Format::Poscar.encodes?(Array(Chem::Structure)).should be_false
      Chem::Format::Poscar.encodes?(Array(Chem::AtomCollection)).should be_false
      Chem::Format::XYZ.encodes?(Array(Int32)).should be_false
    end
  end

  describe "#extnames" do
    it "returns registered file extensions" do
      Chem::Format::Image.extnames.should eq [".bmp", ".jpg", ".png", ".tiff"]
      Chem::Format::CAD.extnames.should eq [".cad"]
    end
  end

  describe "#file_patterns" do
    it "returns the file patterns" do
      Chem::Format::License.file_patterns.should eq ["SPEC", "LIC*", "*KE", "*any*"]
    end
  end

  describe "#reader" do
    it "returns the format's reader class" do
      Chem::Format::XYZ.reader(Chem::Structure).should eq Chem::XYZ::Reader
      Chem::Format::XYZ.reader(Array(Chem::Structure)).should eq Chem::XYZ::Reader
      Chem::Format::Poscar.reader(Chem::Structure).should eq Chem::VASP::Poscar::Reader
      Chem::Format::DX.reader(Chem::Spatial::Grid).should eq Chem::DX::Reader
    end

    it "raises if format is write only" do
      expect_raises ArgumentError, "VMD format is write only" do
        Chem::Format::VMD.reader(Chem::Structure)
      end
    end

    it "raises if format does not decode the given type" do
      expect_raises ArgumentError, "DX format cannot read Chem::Structure" do
        Chem::Format::DX.reader(Chem::Structure)
      end
    end

    it "raises with an array for a single-entry format" do
      expect_raises ArgumentError, "Poscar format cannot read Array(Chem::Structure)" do
        Chem::Format::Poscar.reader(Array(Chem::Structure))
      end
    end

    it "raises with an array if format does not decode the given type" do
      expect_raises ArgumentError, "XYZ format cannot read Array(String)" do
        Chem::Format::XYZ.reader(Array(String))
      end
    end

    it "fails for non-decoded types", tags: %w(codegen) do
      assert_error "Chem::Format::PDB.reader(Int32)",
        "expected argument #1 to 'Chem::Format#reader' to be \
        Array(Chem::Structure).class, Chem::Spatial::Grid.class or \
        Chem::Structure.class, not Int32.class"
    end

    it "fails with an array for a single-entry type", tags: %w(codegen) do
      assert_error "Chem::Format::DX.reader(Array(Chem::Spatial::Grid))",
        "expected argument #1 to 'Chem::Format#reader' to be \
        Array(Chem::Structure).class, Chem::Spatial::Grid.class or \
        Chem::Structure.class, not Array(Chem::Spatial::Grid).class"
    end
  end

  describe "#writer" do
    it "returns the format's writer class" do
      Chem::Format::XYZ.writer(Chem::Structure).should eq Chem::XYZ::Writer
      Chem::Format::XYZ.writer(Chem::AtomCollection).should eq Chem::XYZ::Writer
      Chem::Format::Poscar.writer(Chem::Structure).should eq Chem::VASP::Poscar::Writer
      Chem::Format::DX.writer(Chem::Spatial::Grid).should eq Chem::DX::Writer

      Chem::Format::XYZ.writer(Array(Chem::Structure)).should eq Chem::XYZ::Writer
      Chem::Format::XYZ.writer(Array(Chem::AtomCollection)).should eq Chem::XYZ::Writer
    end

    it "raises if format is read only" do
      expect_raises ArgumentError, "CAD format is read only" do
        Chem::Format::CAD.writer(String)
      end
    end

    it "raises if format does not encode the given type" do
      expect_raises ArgumentError, "DX format cannot write Chem::Structure" do
        Chem::Format::DX.writer(Chem::Structure)
      end
    end

    it "raises with an array for a single-entry format" do
      expect_raises ArgumentError, "Gen format cannot write Array(Chem::Structure)" do
        Chem::Format::Gen.writer(Array(Chem::Structure))
      end
    end

    it "raises with an array if format does not encode the given type" do
      expect_raises ArgumentError, "XYZ format cannot write Array(String)" do
        Chem::Format::XYZ.writer(Array(String))
      end
    end

    it "fails for non-encoded types", tags: %w(codegen) do
      assert_error "Chem::Format::PDB.writer(Int32)",
        "expected argument #1 to 'Chem::Format#writer' to be \
        Array(Chem::AtomCollection).class, Array(Chem::Structure).class, \
        Chem::AtomCollection:Module, Chem::Spatial::Grid.class or \
        Chem::Structure.class, not Int32.class"
    end

    it "fails with an array for a single-entry type", tags: %w(codegen) do
      assert_error "Chem::Format::DX.writer(Array(Chem::Spatial::Grid))",
        "expected argument #1 to 'Chem::Format#writer' to be \
        Array(Chem::AtomCollection).class, Array(Chem::Structure).class, \
        Chem::AtomCollection:Module, Chem::Spatial::Grid.class or \
        Chem::Structure.class, not Array(Chem::Spatial::Grid).class"
    end
  end

  describe ".names" do
    it "returns registered file formats" do
      Chem::Format.names.includes?("CAD").should be_true
      Chem::Format.names.includes?("Image").should be_true
    end
  end
end
