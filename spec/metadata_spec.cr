require "./spec_helper"

describe Chem::Metadata::Any do
  describe "#raw" do
    it "returns the enclosed value" do
      any = Chem::Metadata::Any.new("1")
      any.raw.should be_a String
      any.raw.should eq "1"
    end
  end

  describe "#as_bool" do
    it "returns a bool" do
      Chem::Metadata::Any.new(true).as_bool.should eq true
      Chem::Metadata::Any.new(false).as_bool.should eq false
    end

    it "raises if invalid" do
      expect_raises(TypeCastError) { Chem::Metadata::Any.new(1).as_bool }
    end
  end

  describe "#as_bool?" do
    it "returns a bool" do
      Chem::Metadata::Any.new(true).as_bool?.should eq true
      Chem::Metadata::Any.new(false).as_bool?.should eq false
    end

    it "returns nil if invalid" do
      Chem::Metadata::Any.new(rand).as_bool?.should be_nil
    end
  end

  describe "#as_f" do
    it "returns a float" do
      Chem::Metadata::Any.new(Math::PI).as_f.should eq Math::PI
      Chem::Metadata::Any.new(Int32::MAX).as_f.should be_a Float64
      Chem::Metadata::Any.new(Int32::MAX).as_f.should eq Int32::MAX.to_f
    end

    it "raises if invalid" do
      expect_raises(TypeCastError) { Chem::Metadata::Any.new("1").as_f }
    end
  end

  describe "#as_f?" do
    it "returns a float" do
      Chem::Metadata::Any.new(Math::PI).as_f?.should eq Math::PI
      Chem::Metadata::Any.new(Int32::MAX).as_f?.should be_a Float64
      Chem::Metadata::Any.new(Int32::MAX).as_f?.should eq Int32::MAX.to_f
    end

    it "returns nil if invalid" do
      Chem::Metadata::Any.new("1").as_f?.should be_nil
    end
  end

  describe "#as_i" do
    it "returns an integer" do
      Chem::Metadata::Any.new(Int32::MAX).as_i.should eq Int32::MAX
    end

    it "raises if invalid" do
      expect_raises(TypeCastError) { Chem::Metadata::Any.new(Math::PI).as_i }
    end
  end

  describe "#as_i?" do
    it "returns an integer" do
      Chem::Metadata::Any.new(Int32::MAX).as_i?.should eq Int32::MAX
    end

    it "returns nil if invalid" do
      Chem::Metadata::Any.new(Math::PI).as_i?.should be_nil
    end
  end

  describe "#as_s" do
    it "returns a string" do
      Chem::Metadata::Any.new("Foo").as_s.should eq "Foo"
    end

    it "raises if invalid" do
      expect_raises(TypeCastError) { Chem::Metadata::Any.new(Math::PI).as_s }
    end
  end

  describe "#as_s?" do
    it "returns a string" do
      Chem::Metadata::Any.new("Foo").as_s?.should eq "Foo"
    end

    it "returns nil if invalid" do
      Chem::Metadata::Any.new(Math::PI).as_s?.should be_nil
    end
  end

  describe "#inspect" do
    it "inspect the object" do
      Chem::Metadata::Any.new(Math::PI).inspect.should eq "Chem::Metadata::Any(#{Math::PI})"
    end
  end

  describe "#to_s" do
    it "returns the string representation of the enclosed value" do
      Chem::Metadata::Any.new(Math::PI).to_s.should eq Math::PI.to_s
    end
  end
end
