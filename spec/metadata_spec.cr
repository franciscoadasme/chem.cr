require "./spec_helper"

describe Chem::Metadata::Any do
  describe "#==" do
    it "compares the enclosed values" do
      Chem::Metadata::Any.new("123").should eq Chem::Metadata::Any.new("123")
      Chem::Metadata::Any.new("123").should_not eq Chem::Metadata::Any.new(123)
    end

    it "compares the enclosed value with any value" do
      Chem::Metadata::Any.new("123").should eq "123"
      Chem::Metadata::Any.new("123").should_not eq 123
      Chem::Metadata::Any.new("123").should_not eq [] of Int32
    end
  end

  describe "#as_a" do
    it "returns an array of any" do
      Chem::Metadata::Any.new([1, 2, 3]).as_a.should be_a Array(Chem::Metadata::Any)
      Chem::Metadata::Any.new([1, 2, 3]).as_a.should eq [1, 2, 3]
      Chem::Metadata::Any.new(%w(1 2 3)).as_a.should eq %w(1 2 3)
      Chem::Metadata::Any.new(%w(1 2 3)).as_a.should_not eq [1, 2, 3]
      Chem::Metadata::Any.new([1, 2, 3]).as_a.sum(&.as_i).should eq 6
      Chem::Metadata::Any.new([1, 2, 3]).as_a[2].as_i.should eq 3
    end

    it "returns a typed array" do
      any = Chem::Metadata::Any.new([1, 2, 3])
      any.as_a(Int32).should be_a Array(Int32)
      any.as_a(Int32).should eq [1, 2, 3]
      any.as_a(Int32).should_not eq %w(1 2 3)
      any.as_a(Int32).sum.should eq 6
    end

    it "raises if invalid" do
      expect_raises(TypeCastError) { Chem::Metadata::Any.new("1").as_a }
    end

    it "raises if invalid array type" do
      expect_raises(TypeCastError) do
        Chem::Metadata::Any.new([1, 2, 3]).as_a(String)
      end
    end
  end

  describe "#as_a?" do
    it "returns an array of any" do
      Chem::Metadata::Any.new([1, 2, 3]).as_a?.should be_a Array(Chem::Metadata::Any)
      Chem::Metadata::Any.new([1, 2, 3]).as_a?.should eq [1, 2, 3]
      Chem::Metadata::Any.new(%w(1 2 3)).as_a?.should eq %w(1 2 3)
      Chem::Metadata::Any.new(%w(1 2 3)).as_a?.should_not eq [1, 2, 3]
      Chem::Metadata::Any.new([1, 2, 3]).as_a?.try(&.sum(&.as_i)).should eq 6
      Chem::Metadata::Any.new([1, 2, 3]).as_a?.try(&.[2].as_i).should eq 3
    end

    it "returns a typed array" do
      any = Chem::Metadata::Any.new([1, 2, 3])
      any.as_a?(Int32).should be_a Array(Int32)
      any.as_a?(Int32).should eq [1, 2, 3]
      any.as_a?(Int32).should_not eq %w(1 2 3)
      any.as_a?(Int32).try(&.sum).should eq 6
    end

    it "returns nil if invalid" do
      Chem::Metadata::Any.new("1").as_a?.should be_nil
    end

    it "returns nil if invalid array type" do
      Chem::Metadata::Any.new([1, 2, 3]).as_a?(String).should be_nil
    end
  end

  describe "#as_2a" do
    it "returns a nested typed array" do
      any = Chem::Metadata::Any.new([[1, 2], [3]])
      any.as_2a(Int32).should be_a Array(Array(Int32))
      any.as_2a(Int32).should eq [[1, 2], [3]]
      any.as_2a(Int32).should_not eq %w(1 2 3)
      any.as_2a(Int32).sum(&.sum).should eq 6
    end

    it "raises if invalid" do
      expect_raises(TypeCastError) { Chem::Metadata::Any.new("1").as_2a(String) }
      expect_raises(TypeCastError) { Chem::Metadata::Any.new([1]).as_2a(Int32) }
    end

    it "raises if invalid array type" do
      expect_raises(TypeCastError) do
        Chem::Metadata::Any.new([[1, 2], [3]]).as_2a(String)
      end
    end
  end

  describe "#as_2a?" do
    it "returns a nested typed array" do
      any = Chem::Metadata::Any.new([[1, 2], [3]])
      any.as_2a?(Int32).should be_a Array(Array(Int32))
      any.as_2a?(Int32).should eq [[1, 2], [3]]
      any.as_2a?(Int32).should_not eq %w(1 2 3)
      any.as_2a?(Int32).try(&.sum(&.sum)).should eq 6
    end

    it "returns nil if invalid" do
      Chem::Metadata::Any.new("1").as_2a?(String).should be_nil
      Chem::Metadata::Any.new([1]).as_2a?(Int32).should be_nil
    end

    it "returns nil if invalid array type" do
      Chem::Metadata::Any.new([[1, 2], [3]]).as_2a?(String).should be_nil
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
      Chem::Metadata::Any.new(Math::PI).inspect.should eq "#{Chem::Metadata::Any}(#{Math::PI})"
      Chem::Metadata::Any.new("foo").inspect.should eq %(#{Chem::Metadata::Any}("foo"))
    end
  end

  describe "#raw" do
    it "returns the enclosed value" do
      any = Chem::Metadata::Any.new("1")
      any.raw.should be_a String
      any.raw.should eq "1"
    end
  end

  describe "#to_s" do
    it "returns the string representation of the enclosed value" do
      Chem::Metadata::Any.new(Math::PI).to_s.should eq Math::PI.to_s
    end
  end
end

describe Chem::Metadata do
  describe "#[]" do
    it "returns the value for a key" do
      fake_metadata["str"].should be_a Chem::Metadata::Any
      fake_metadata["str"].should eq "Foo"
    end

    it "raises if key does not exist" do
      expect_raises(KeyError) { fake_metadata["foo"] }
    end
  end

  describe "#[]=" do
    it "sets a value for key" do
      metadata = fake_metadata
      metadata["foo"] = "bar"
      metadata["foo"].should be_a Chem::Metadata::Any
      metadata["foo"].should eq "bar"
    end
  end

  describe "#[]?" do
    it "returns the value for a key" do
      fake_metadata["int"]?.should be_a Chem::Metadata::Any
      fake_metadata["int"]?.should eq 123
    end

    it "returns nil key does not exist" do
      fake_metadata["foo"]?.should be_nil
    end
  end

  describe "#each" do
    it "yields each key-value pair" do
      entries = [] of {String, Chem::Metadata::Any}
      fake_metadata.each { |kv| entries << kv }
      entries.should eq fake_metadata.to_a
    end

    it "returns an iterator of each key-value pair" do
      fake_metadata.each.to_a.should eq fake_metadata.to_a
    end
  end

  describe "#clear" do
    it "empties the metadata" do
      fake_metadata.clear.should be_empty
    end
  end

  describe "#delete" do
    it "removes a key-value pair" do
      metadata = fake_metadata
      metadata.delete("float").should eq 1.234
      metadata.keys.should eq %w(str int bool)
    end

    it "yields if key does not exist" do
      fake_metadata.delete("foo") { |key| key.upcase }.should eq "FOO"
    end
  end

  describe "#each" do
    it "yields each key-value pair" do
      entries = [] of {String, Chem::Metadata::Any}
      fake_metadata.each { |kv| entries << kv }
      entries.should eq fake_metadata.to_a
    end

    it "returns an iterator of each key-value pair" do
      fake_metadata.each.to_a.should eq fake_metadata.to_a
    end
  end

  describe "#each_key" do
    it "yields each key" do
      keys = [] of String
      fake_metadata.each_key { |key| keys << key }
      keys.should eq fake_metadata.keys
    end

    it "returns an iterator of each key" do
      fake_metadata.each_key.to_a.should eq fake_metadata.keys
    end
  end

  describe "#each_value" do
    it "yields each value" do
      values = [] of Chem::Metadata::Any
      fake_metadata.each_value { |value| values << value }
      values.should eq fake_metadata.values
    end

    it "returns an iterator of each value" do
      fake_metadata.each_value.to_a.should eq fake_metadata.values
    end
  end

  describe "#empty?" do
    it "returns true if empty" do
      Chem::Metadata.new.empty?.should be_true
    end

    it "returns false if not empty" do
      fake_metadata.empty?.should be_false
    end
  end

  describe "#fetch" do
    it "returns the value for key" do
      fake_metadata.fetch("str", Math::PI).should eq "Foo"
    end

    it "returns the default value if key does not exist" do
      fake_metadata.fetch("foo", Math::PI).should eq Math::PI
    end

    it "returns the returned value by the block if key does not exist" do
      fake_metadata.fetch("foo") { |key| key.upcase }.should eq "FOO"
    end
  end

  describe "#has_key?" do
    it "returns true if key exists" do
      fake_metadata.has_key?("str").should be_true
    end

    it "returns false if key does not exist" do
      fake_metadata.has_key?("foo").should be_false
    end
  end

  describe "#has_value?" do
    it "returns true if value exists" do
      fake_metadata.has_value?("Foo").should be_true
    end

    it "returns false if value does not exist" do
      fake_metadata.has_value?(Math::PI).should be_false
    end
  end

  describe "#inspect" do
    it "returns a string representation" do
      fake_metadata.inspect.should eq "#{Chem::Metadata}#{fake_metadata}"
    end
  end

  describe "#key_for" do
    it "returns the key for the given value" do
      fake_metadata.key_for("Foo").should eq "str"
    end

    it "returns the returned value by the block if key does not exist" do
      fake_metadata.key_for("Bar") { |value| value.upcase }.should eq "BAR"
    end

    it "raises if value does not exist" do
      expect_raises(KeyError) { fake_metadata.key_for(Math::PI) }
    end
  end

  describe "#key_for?" do
    it "returns the key for the given value" do
      fake_metadata.key_for?("Foo").should eq "str"
    end

    it "returns nil if value does not exist" do
      fake_metadata.key_for?(Math::PI).should be_nil
    end
  end

  describe "#keys" do
    it "returns the keys" do
      fake_metadata.keys.should eq %w(str int float bool)
    end
  end

  describe "#reject!" do
    it "deletes entries when block is truthy" do
      metadata = fake_metadata
      metadata.reject! { |key, value| value.as_i? }
      metadata.keys.should eq %w(str float bool)
    end

    it "deletes the given keys" do
      metadata = fake_metadata
      metadata.reject! %w(str bool)
      metadata.keys.should eq %w(int float)
    end
  end

  describe "#select!" do
    it "deletes entries when block is falsy" do
      metadata = fake_metadata
      metadata.select! { |key, value| value.as_i? }
      metadata.keys.should eq %w(int)
    end

    it "selects the given keys" do
      metadata = fake_metadata
      metadata.select! %w(str bool)
      metadata.keys.should eq %w(str bool)
    end
  end

  describe "#size" do
    it "returns the number of key-value pairs" do
      fake_metadata.size.should eq 4
      fake_metadata.clear.size.should eq 0
    end
  end

  describe "#to_a" do
    it "returns the key-value pairs" do
      fake_metadata.to_a.should eq [
        {"str", Chem::Metadata::Any.new("Foo")},
        {"int", Chem::Metadata::Any.new(123)},
        {"float", Chem::Metadata::Any.new(1.234)},
        {"bool", Chem::Metadata::Any.new(true)},
      ]
    end
  end

  describe "#to_s" do
    it "returns the string representation" do
      fake_metadata.to_s.should eq \
        %({"str" => "Foo", "int" => 123, "float" => 1.234, "bool" => true})
    end
  end

  describe "#update" do
    it "updates a value" do
      metadata = fake_metadata
      metadata.update("int", &.as_i.*(2))
      metadata["int"].should eq 246
    end

    it "raises if key does not exist" do
      expect_raises(KeyError) { fake_metadata.update("foo") { 2 } }
    end
  end

  describe "#values" do
    it "returns the values" do
      fake_metadata.values.should eq ["Foo", 123, 1.234, true]
    end
  end

  describe "#values_at" do
    it "returns the values" do
      fake_metadata.values_at("str", "float").should eq({"Foo", 1.234})
      fake_metadata.values_at(["str", "float"]).should eq ["Foo", 1.234]
    end

    it "raises if a key does not exist" do
      expect_raises(KeyError) { fake_metadata.values_at("foo") }
    end
  end
end

private def fake_metadata : Chem::Metadata
  metadata = Chem::Metadata.new
  metadata["str"] = "Foo"
  metadata["int"] = 123
  metadata["float"] = 1.234
  metadata["bool"] = true
  metadata
end
