require "./spec_helper"

describe Chem::RegisterFormat, tags: %w(register_format codegen) do
  it "fails on duplicate format" do
    assert_error <<-EOS, "Format F in B::F is registered to A::F"
      @[Chem::RegisterFormat]
      module A::F; end
      @[Chem::RegisterFormat]
      module B::F; end
      EOS
  end

  it "fails on duplicate extension" do
    assert_error <<-EOS, "Extension .txt in B is registered to A"
      @[Chem::RegisterFormat(ext: %w(.txt))]
      module A; end
      @[Chem::RegisterFormat(ext: %w(.txt))]
      module B; end
      EOS
  end

  it "fails on duplicate file pattern" do
    message = "File pattern *foo* in B is registered to A"
    assert_error <<-EOS, message
      @[Chem::RegisterFormat(names: %w(FOO*))]
      module A; end
      @[Chem::RegisterFormat(names: %w(*foo*))]
      module B; end
      EOS
  end

  it "fails on reader not including FormatReader" do
    message = "A::Reader must include Chem::FormatReader(T)"
    assert_error <<-EOS, message
      @[Chem::RegisterFormat]
      module A
        class Reader; end
      end
      EOS
  end

  it "fails on writer not including FormatWriter" do
    message = "A::Writer must include Chem::FormatWriter(T)"
    assert_error <<-EOS, message
      @[Chem::RegisterFormat]
      module A
        class Writer; end
      end
      EOS
  end

  it "generates read and write methods on encoded type" do
    assert_code <<-EOS
      struct A; end

      @[Chem::RegisterFormat]
      module Foo
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
      module Foo
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
      module Foo
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
      module Foo
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
      module Foo
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
      module Foo
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
      x = Array(Chem::Structure).read spec_file("models.pdb")
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

    it "fails for non-encoded types", tags: %w(codegen) do
      assert_error "Array(Int32).read(IO::Memory.new, :xyz)",
        "undefined method 'read' for Array(Int32).class"
    end

    it "fails with an array for a single-entry type", tags: %w(codegen) do
      assert_error "Array(Chem::Spatial::Grid).read IO::Memory.new, :xyz",
        "undefined method 'read' for Array(Chem::Spatial::Grid).class"
    end
  end

  describe "#write" do
    it "writes in a multiple-entry format" do
      x = Array(Chem::Structure).from_pdb spec_file("models.pdb")
      String.build { |io| x.write(io, :xyz) }.should eq <<-XYZ
        5

        N     5.606    4.546   11.941
        C     5.598    5.767   11.082
        C     6.441    5.527    9.850
        O     6.052    5.933    8.744
        C     6.022    6.977   11.891
        5

        N     7.212   15.334    0.966
        C     6.614   16.317    1.913
        C     5.212   15.936    2.350
        O     4.782   16.166    3.495
        C     6.605   17.695    1.246
        5

        N     5.408   13.012    4.694
        C     5.879   13.502    6.026
        C     4.696   13.908    6.882
        O     4.528   13.422    8.025
        C     6.880   14.615    5.830
        5

        N    22.055   14.701    7.032
        C    22.019   13.242    7.020
        C    21.944   12.628    8.396
        O    21.869   11.387    8.435
        C    23.246   12.697    6.275

        XYZ
    end

    it "raises for a single-entry format" do
      expect_raises ArgumentError, "Poscar format cannot write Array(Chem::Structure)" do
        Array(Chem::Structure).new.write(IO::Memory.new, :poscar)
      end
    end

    it "fails for non-encoded types", tags: %w(codegen) do
      assert_error "[1].write(IO::Memory.new, :xyz)",
        "undefined method 'write' for Array(Int32)"
    end

    it "fails with an array for a single-entry type", tags: %w(codegen) do
      assert_error "Array(Chem::Spatial::Grid).new.write IO::Memory.new, :xyz",
        "undefined method 'write' for Array(Chem::Spatial::Grid)"
    end
  end
end
