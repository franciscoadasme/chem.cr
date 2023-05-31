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

describe Chem::FormatReader::Indexable do
  it "reads multiple entries" do
    io = IO::Memory.new "3 2 4\n   1   2\n  10  20\n 100 200\n"
    reader = IndexableReader.new(io)
    reader.n_entries.should eq 3
    reader.next_entry.should eq [1, 2]
    reader.next_entry.should eq [10, 20]
    reader.next_entry.should eq [100, 200]
    reader.next_entry.should be_nil
  end

  it "reads an entry at index" do
    io = IO::Memory.new "3 2 4\n   1   2\n  10  20\n 100 200\n"
    reader = IndexableReader.new(io)
    reader.n_entries.should eq 3
    reader.read_entry(2).should eq [100, 200]
  end

  it "raises if index is invalid" do
    io = IO::Memory.new "3 2 4\n   1   2\n  10  20\n 100 200\n"
    reader = IndexableReader.new(io)
    expect_raises(IndexError) { reader.read_entry 10 }
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

private class IndexableReader
  include Chem::FormatReader(Array(Int32))
  include Chem::FormatReader::Indexable(Array(Int32))

  @n_items : Int32
  @width : Int32

  getter entry_index : Int32
  getter n_entries : Int32

  def initialize(@io : IO, @sync_close : Bool = false)
    @n_entries, @n_items, @width = @io.gets.not_nil!.split.map(&.to_i)
    @entry_index = 0
    @data_offset = @io.pos
  end

  protected def decode_entry : Array(Int32)
    @io.gets.not_nil!.split.map(&.to_i)
  end

  def next_entry : T?
    return nil unless @entry_index < @n_entries
    check_open
    obj = decode_entry
    @read = true
    @entry_index += 1
    obj
  end

  def skip_to_entry(index : Int) : Nil
    check_open
    raise IndexError.new unless 0 <= index < @n_entries
    @io.pos = @data_offset + index * (@n_items * @width + 1)
    @entry_index = index
  end
end
