require "../../spec_helper"

describe IO::Wrapper do
  it "does not generate convenience methods on abstract class" do
    assert_error <<-EOS, "undefined method 'open' for A.class"
      abstract class A
        include IO::Wrapper
      end
      A.open(IO::Memory.new) {}
      EOS
  end

  it "does not generate convenience methods on modules" do
    assert_error <<-EOS, "undefined method 'open' for A:Module"
      module A
        include IO::Wrapper
      end
      A.open(IO::Memory.new) {}
      EOS
  end

  it "generates convenience methods on subclasses" do
    assert_code <<-EOS
      abstract class A
        include IO::Wrapper
      end
      abstract class B < A; end
      abstract class C < B; end
      class D < C; end
      D.open(IO::Memory.new) {}
      EOS
  end

  it "generates convenience methods on including types" do
    assert_code <<-EOS
      module A
        include IO::Wrapper
      end
      module B
        include A
      end
      module C
        include B
      end
      class D
        include C
      end
      D.open(IO::Memory.new) {}
      EOS
  end

  it "finds initialize in superclass" do
    assert_code <<-EOS
      abstract class A
        include IO::Wrapper
        def initialize(@io : IO, foo : Int32, sync_close : Bool = false); end
      end
      abstract class B < A
        def initialize(@io : IO, bar : String, sync_close : Bool = false); end
      end
      abstract class C < B; end
      class D < C; end
      D.open(IO::Memory.new, bar: "bar") {}
      EOS
  end

  it "handles argument internal names" do
    assert_code <<-EOS
      struct A
        include IO::Wrapper
        def initialize(@io : IO, foo bar : Int32, sync_close : Bool = false); end
      end
      A.new(IO::Memory.new, foo: 1)
      A.new("asd", foo: 1)
      A.open(IO::Memory.new, foo: 1) {}
      A.open("asd", foo: 1) {}
      EOS
  end

  it "fails on invalid first argument" do
    message = "First argument of `BadArgumentIO#initialize` must be \
               `io : IO`, not `foo : String`"
    assert_error <<-EOS, message
      class BadArgumentIO
        include IO::Wrapper

        def initialize(foo : String, bar : Int32); end
      end
      EOS
  end

  it "fails on missing argument sync_close" do
    message = "Missing argument `sync_close : Bool = false` in \
               `MissingArgumentIO#initialize`"
    assert_error <<-EOS, message
      class MissingArgumentIO
        include IO::Wrapper

        def initialize(io : IO); end
      end
      EOS
  end

  it "fails on invalid type of argument sync_close" do
    message = "Argument `sync_close` of `BadArgumentTypeIO#initialize` \
               must be `sync_close : Bool = false`, not `sync_close = 1`"
    assert_error <<-EOS, message
      class BadArgumentTypeIO
        include IO::Wrapper

        def initialize(io : IO, sync_close = 1); end
      end
      EOS
  end

  describe "#initialize" do
    it "initializes from an IO" do
      io = LineIO.new IO::Memory.new, chomp: true, sync_close: true
      io.chomp?.should be_true
      io.sync_close.should be_true
    end

    it "initializes from an IO (no options)" do
      io = SimpleIO.new IO::Memory.new
      io.closed?.should be_false
      io.close
    end

    it "initializes from a path" do
      tempfile = File.tempfile(".txt")
      io = LineIO.new tempfile.path, chomp: true
      io.chomp?.should be_true
      io.sync_close.should be_true
      io.close
      tempfile.delete
    end

    it "initializes from a path (no options)" do
      tempfile = File.tempfile(".txt")
      io = SimpleIO.new tempfile.path
      io.closed?.should be_false
      io.close
      tempfile.delete
    end

    it "initializes from a path in write mode" do
      tempfile = File.tempfile(".txt")
      io = WriteIO.new tempfile.path
      io << "abc"
      io.close
      tempfile.delete
    end
  end

  describe ".open" do
    it "opens an IO, yield it, closes it, and returns the last value" do
      io = IO::Memory.new "abc\ndef\n"
      line = LineIO.open(io, chomp: true, sync_close: true) do |line_io|
        line_io.next_line
        line_io.next_line
      end
      io.closed?.should be_true
      line.should eq "def"
    end

    it "opens an IO (no options)" do
      io = IO::Memory.new "abc\ndef\n"
      line = SimpleIO.open(io, sync_close: true) do |simple_io|
        simple_io.gets
      end
      io.closed?.should be_true
      line.should eq "abc"
    end

    it "opens a file, yield it, closes it, and returns the last value" do
      tempfile = File.tempfile(".txt") do |io|
        io.puts "abc"
        io.puts "def"
      end
      line = LineIO.open(tempfile.path, chomp: true) do |line_io|
        line_io.next_line
        line_io.next_line
      end
      line.should eq "def"
      tempfile.delete
    end

    it "opens an IO (no options)" do
      tempfile = File.tempfile(".txt") do |io|
        io.puts "abc"
        io.puts "def"
      end
      line = SimpleIO.open(tempfile.path) do |simple_io|
        simple_io.gets
      end
      line.should eq "abc"
      tempfile.delete
    end
  end

  describe "#closed?" do
    it "tells if the IO is closed" do
      io = LineIO.new IO::Memory.new
      io.closed?.should be_false
      io.close
      io.closed?.should be_true
    end
  end

  describe "#close" do
    it "closes the IO" do
      io = LineIO.new IO::Memory.new
      io.close
      expect_raises IO::Error, "Closed IO" do
        io.next_line
      end
    end

    it "closes the underlying IO" do
      io = IO::Memory.new
      fake_io = LineIO.new io, sync_close: true
      fake_io.close
      io.closed?.should be_true
    end
  end
end

private class LineIO
  include IO::Wrapper

  getter? chomp : Bool

  def initialize(@io : IO, @chomp = false, @sync_close : Bool = false)
  end

  def next_line : String?
    check_open
    @io.gets chomp: chomp?
  end
end

private class SimpleIO
  include IO::Wrapper

  delegate gets, to: @io
end

private class WriteIO
  include IO::Wrapper

  FILE_MODE = "w"

  delegate :<<, to: @io
end
