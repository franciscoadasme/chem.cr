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

  it "generates read methods on array" do
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
      end

      Array(A).from_foo(IO::Memory.new).as(Array(A))
      Array(A).from_foo("a.foo").as(Array(A))
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
