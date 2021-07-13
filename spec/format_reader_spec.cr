require "./spec_helper"

describe Chem::FormatReader do
  describe "#read_entry" do
    it "returns the encoded object" do
      io = IO::Memory.new "825\n"
      reader = FooReader.new io
      obj = reader.read_entry
      reader.read?.should be_true
      obj.should be_a Foo
      obj.num.should eq 825
      expect_raises(IO::EOFError) { io.read_line }
    end

    it "raises on closed IO" do
      reader = FooReader.new IO::Memory.new
      reader.close
      expect_raises(IO::Error, "Closed IO") do
        reader.read_entry
      end
    end

    it "raises if entry was already read" do
      reader = FooReader.new IO::Memory.new("1\n")
      reader.read_entry
      reader.read?.should be_true
      expect_raises(IO::Error, "Entry already read") do
        reader.read_entry
      end
    end
  end
end

private struct Foo
  getter num : Int32

  def initialize(@num : Int32)
  end
end

private class FooReader
  include Chem::FormatReader(Foo)

  protected def decode_entry : Foo
    Foo.new @io.read_line.to_i
  end
end
