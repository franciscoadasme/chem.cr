require "./spec_helper"

describe Chem::RegisterFormat do
  it "fails on duplicate format" do
    assert_error <<-EOS, "Format F in Chem::B::F is registered to Chem::A::F"
      @[Chem::RegisterFormat]
      module Chem::A::F; end
      @[Chem::RegisterFormat]
      module Chem::B::F; end
      EOS
  end

  it "fails on duplicate extension" do
    assert_error <<-EOS, "Extension .txt in Chem::B is registered to Chem::A"
      @[Chem::RegisterFormat(ext: %w(.txt))]
      module Chem::A; end
      @[Chem::RegisterFormat(ext: %w(.txt))]
      module Chem::B; end
      EOS
  end

  it "fails on duplicate file pattern" do
    message = "File pattern *foo* in Chem::B is registered to Chem::A"
    assert_error <<-EOS, message
      @[Chem::RegisterFormat(names: %w(FOO*))]
      module Chem::A; end
      @[Chem::RegisterFormat(names: %w(*foo*))]
      module Chem::B; end
      EOS
  end

  it "fails on reader not including FormatReader" do
    message = "Chem::A::Reader must include Chem::FormatReader(T)"
    assert_error <<-EOS, message
      @[Chem::RegisterFormat]
      module Chem::A
        class Reader; end
      end
      EOS
  end

  it "fails on writer not including FormatWriter" do
    message = "Chem::A::Writer must include Chem::FormatWriter(T)"
    assert_error <<-EOS, message
      @[Chem::RegisterFormat]
      module Chem::A
        class Writer; end
      end
      EOS
  end

  it "generates read and write methods on encoded type" do
    assert_code <<-EOS
      struct A; end

      @[Chem::RegisterFormat]
      module Chem::Foo
        class Reader
          include Chem::FormatReader(A)

          def initialize(@io : IO, foo : Int32 = 1, sync_close : Bool = false); end

          protected def decode_entry : A
            A.new
          end
        end
        class Writer
          include Chem::FormatWriter(A)

          def initialize(@io : IO, bar : String = "bar", sync_close : Bool = false); end
          def encode_entry(obj : A) : Nil; end
        end
      end

      A.from_foo(IO::Memory.new, foo: 1).as(A)
      A.from_foo("a.foo", foo: 1).as(A)
      A.read(IO::Memory.new, Chem::Format::Foo).as(A)
      A.read(IO::Memory.new, "foo").as(A)
      A.read("a.foo", Chem::Format::Foo).as(A)
      A.read("a.foo", "foo").as(A)
      A.read("a.foo").as(A)

      A.new.to_foo(bar: "1").as(String)
      A.new.to_foo(IO::Memory.new, bar: "1")
      A.new.to_foo("a.foo", bar: "1")
      A.new.write(IO::Memory.new, Chem::Format::Foo)
      A.new.write(IO::Memory.new, "foo")
      A.new.write("a.foo", Chem::Format::Foo)
      A.new.write("a.foo", "foo")
      A.new.write("a.foo")
      EOS
  end

  it "generates read methods on header type" do
    assert_code <<-EOS
      struct A; end
      struct A::Info; end

      @[Chem::RegisterFormat]
      module Chem::Foo
        class Reader
          include Chem::FormatReader(A)
          include Chem::FormatReader::Headed(A::Info)

          protected def decode_entry : A
            A.new
          end

          protected def decode_header : A::Info
            A::Info.new
          end
        end
      end

      A::Info.from_foo(IO::Memory.new).as(A::Info)
      A::Info.from_foo("a.foo").as(A::Info)
      A::Info.read(IO::Memory.new, Chem::Format::Foo).as(A::Info)
      A::Info.read(IO::Memory.new, "foo").as(A::Info)
      A::Info.read("a.foo", Chem::Format::Foo).as(A::Info)
      A::Info.read("a.foo", "foo").as(A::Info)
      A::Info.read("a.foo").as(A::Info)
      EOS
  end

  it "generates read methods on attached type" do
    assert_code <<-EOS
      struct A; end
      struct B; end

      @[Chem::RegisterFormat]
      module Chem::Foo
        class Reader
          include Chem::FormatReader(A)
          include Chem::FormatReader::Attached(B)

          protected def decode_entry : A
            A.new
          end

          protected def decode_attached : B
            B.new
          end
        end
      end

      B.from_foo(IO::Memory.new).as(B)
      B.from_foo("a.foo").as(B)
      B.read(IO::Memory.new, Chem::Format::Foo).as(B)
      B.read(IO::Memory.new, "foo").as(B)
      B.read("a.foo", Chem::Format::Foo).as(B)
      B.read("a.foo", "foo").as(B)
      B.read("a.foo").as(B)
      EOS
  end

  it "generates read and write methods on array" do
    assert_code <<-EOS
      struct A; end

      @[Chem::RegisterFormat]
      module Chem::Foo
        class Reader
          include Chem::FormatReader(A)
          include Chem::FormatReader::MultiEntry(A)

          protected def decode_entry : A
            A.new
          end

          def skip_entry : Nil; end
        end

        class Writer
          include Chem::FormatWriter(A)
          include Chem::FormatWriter::MultiEntry(A)

          protected def encode_entry(obj : A) : Nil; end
        end
      end

      Array(A).from_foo(IO::Memory.new).as(Array(A))
      Array(A).from_foo("a.foo").as(Array(A))
      Array(A).read(IO::Memory.new, Chem::Format::Foo).as(Array(A))
      Array(A).read(IO::Memory.new, "foo").as(Array(A))
      Array(A).read("a.foo", Chem::Format::Foo).as(Array(A))
      Array(A).read("a.foo", "foo").as(Array(A))
      Array(A).read("a.foo").as(Array(A))
      Array(A).new.to_foo
      Array(A).new.to_foo("a.foo")
      Array(A).new.write(IO::Memory.new, Chem::Format::Foo)
      Array(A).new.write(IO::Memory.new, "foo")
      Array(A).new.write("a.foo", Chem::Format::Foo)
      Array(A).new.write("a.foo", "foo")
      Array(A).new.write("a.foo")
      EOS
  end

  it "does not generate read methods on array for single-entry formats" do
    assert_error <<-EOS, "undefined method 'from_foo' for Array(A).class"
      struct A; end

      @[Chem::RegisterFormat]
      module Chem::Foo
        class Reader
          include Chem::FormatReader(A)

          protected def decode_entry : A
            2
          end
        end
      end

      Array(A).from_foo(IO::Memory.new)
      EOS
  end

  it "raises on incorrect array type" do
    message = "undefined method '.from_foo' for Array(Int32).class"
    assert_error <<-EOS, message
      struct A; end

      @[Chem::RegisterFormat]
      module Chem::Foo
        class Reader
          include Chem::FormatReader(A)
          include Chem::FormatReader::MultiEntry(A)

          protected def decode_entry : A
            A.new
          end

          def skip_entry : Nil; end
        end
      end

      Array(Int32).from_foo(IO::Memory.new)
      EOS
  end
end

describe Array do
  describe ".read" do
    it "returns the entries in a file" do
      x = Array(Chem::Structure).read "spec/data/pdb/models.pdb"
      x.size.should eq 4
    end

    it "raises for a single-entry format" do
      expect_raises ArgumentError, "Poscar format cannot read Array(Chem::Structure)" do
        Array(Chem::Structure).read(IO::Memory.new, :poscar)
      end
    end

    it "raises if format does not decode the given type" do
      expect_raises ArgumentError, "DX format cannot read Array(Chem::Structure)" do
        Array(Chem::Structure).read(IO::Memory.new, :dx)
      end
    end

    it "fails for non-encoded types" do
      assert_error "Array(Int32).read(IO::Memory.new, :xyz)",
        "undefined method 'read' for Array(Int32).class"
    end

    it "fails with an array for a single-entry type" do
      assert_error "Array(Chem::Spatial::Grid).read IO::Memory.new, :xyz",
        "undefined method 'read' for Array(Chem::Spatial::Grid).class"
    end
  end

  describe "#write" do
    it "writes in a multiple-entry format" do
      x = Array(Chem::Structure).from_pdb "spec/data/pdb/models.pdb"
      String.build { |io| x.write(io, :xyz) }.should eq <<-XYZ
        5

        N          5.60600        4.54600       11.94100
        C          5.59800        5.76700       11.08200
        C          6.44100        5.52700        9.85000
        O          6.05200        5.93300        8.74400
        C          6.02200        6.97700       11.89100
        5

        N          7.21200       15.33400        0.96600
        C          6.61400       16.31700        1.91300
        C          5.21200       15.93600        2.35000
        O          4.78200       16.16600        3.49500
        C          6.60500       17.69500        1.24600
        5

        N          5.40800       13.01200        4.69400
        C          5.87900       13.50200        6.02600
        C          4.69600       13.90800        6.88200
        O          4.52800       13.42200        8.02500
        C          6.88000       14.61500        5.83000
        5

        N         22.05500       14.70100        7.03200
        C         22.01900       13.24200        7.02000
        C         21.94400       12.62800        8.39600
        O         21.86900       11.38700        8.43500
        C         23.24600       12.69700        6.27500

        XYZ
    end

    it "raises for a single-entry format" do
      expect_raises ArgumentError, "Poscar format cannot write Array(Chem::Structure)" do
        Array(Chem::Structure).new.write(IO::Memory.new, :poscar)
      end
    end

    it "fails for non-encoded types" do
      assert_error "[1].write(IO::Memory.new, :xyz)",
        "undefined method 'write' for Array(Int32)"
    end

    it "fails with an array for a single-entry type" do
      assert_error "Array(Chem::Spatial::Grid).new.write IO::Memory.new, :xyz",
        "undefined method 'write' for Array(Chem::Spatial::Grid)"
    end
  end
end
