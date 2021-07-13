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

describe Chem::FormatReader::Headed do
  describe "#read_header" do
    it "returns the header object" do
      io = IO::Memory.new <<-EOS
        5
        Foo
        10
        20
        30
        40
        50
        abc
        def
        EOS

      reader = ArrayReader.new io
      header = reader.read_header
      header.title.should eq "Foo"
      header.count.should eq 5
      header.should eq reader.read_header

      reader.read_entry.should eq [10, 20, 30, 40, 50]
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

private struct ArrayHeader
  getter title : String
  getter count : Int32

  def initialize(@count : Int32, @title : String)
  end
end

private class ArrayReader
  include Chem::FormatReader(Array(Int32))
  include Chem::FormatReader::Headed(ArrayHeader)

  protected def decode_entry : Array(Int32)
    Array(Int32).new(read_header.count) do
      @io.read_line.to_i
    end
  end

  protected def decode_header : ArrayHeader
    ArrayHeader.new @io.read_line.to_i, @io.read_line
  end
end
