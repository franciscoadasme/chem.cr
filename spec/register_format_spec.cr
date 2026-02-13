require "./spec_helper"

describe Chem::RegisterFormat, tags: %w(register_format codegen) do
  it "fails on duplicate format" do
    assert_error <<-EOS, "Format F in B::F is registered to A::F"
      struct X; end
      @[Chem::RegisterFormat(ext: %w(.af))]
      module A::F
        def self.read(io : IO | Path | String) : X; X.new; end
      end
      @[Chem::RegisterFormat(ext: %w(.bf))]
      module B::F
        def self.read(io : IO | Path | String) : X; X.new; end
      end
      EOS
  end

  it "fails on duplicate extension" do
    assert_error <<-EOS, "Extension .txt in B is registered to A"
      struct X; end
      @[Chem::RegisterFormat(ext: %w(.txt))]
      module A
        def self.read(io : IO | Path | String) : X; X.new; end
      end
      @[Chem::RegisterFormat(ext: %w(.txt))]
      module B
        def self.read(io : IO | Path | String) : X; X.new; end
      end
      EOS
  end

  it "fails on duplicate file pattern" do
    message = "File pattern *foo* in B is registered to A"
    assert_error <<-EOS, message
      struct X; end
      @[Chem::RegisterFormat(names: %w(FOO*))]
      module A
        def self.read(io : IO | Path | String) : X; X.new; end
      end
      @[Chem::RegisterFormat(names: %w(*foo*))]
      module B
        def self.read(io : IO | Path | String) : X; X.new; end
      end
      EOS
  end

  it "fails on format without read or write methods" do
    message = "Format module must define at least one of: read, read_all, read_info, write"
    assert_error <<-EOS, message
      @[Chem::RegisterFormat(ext: %w(.foo))]
      module A; end
      EOS
  end

  it "generates read and write methods on encoded type" do
    assert_code <<-EOS
      struct A; end

      @[Chem::RegisterFormat(ext: %w(.foo))]
      module Foo
        def self.read(io : IO | Path | String, foo : Int32 = 1) : A
          A.new
        end
        def self.write(io : IO | Path | String, obj : A, bar : String = "bar") : Nil
        end
      end

      A.from_foo(IO::Memory.new, foo: 1).as(A)
      A.from_foo("a.foo", foo: 1).as(A)
      A.read(IO::Memory.new, Foo).as(A)
      A.read("a.foo", Foo).as(A)
      A.read("a.foo").as(A)

      A.new.to_foo(bar: "1").as(String)
      A.new.to_foo(IO::Memory.new, bar: "1")
      A.new.to_foo("a.foo", bar: "1")
      A.new.write(IO::Memory.new, Foo)
      A.new.write("a.foo", Foo)
      A.new.write("a.foo")
      EOS
  end

  it "generates read methods on header type" do
    assert_code <<-EOS
      struct A; end
      struct A::Info; end

      @[Chem::RegisterFormat(ext: %w(.foo))]
      module Foo
        def self.read(io : IO | Path | String) : A
          A.new
        end
        def self.read_info(io : IO | Path | String) : A::Info
          A::Info.new
        end
      end

      A::Info.from_foo(IO::Memory.new).as(A::Info)
      A::Info.from_foo("a.foo").as(A::Info)
      A::Info.read(IO::Memory.new, Foo).as(A::Info)
      A::Info.read("a.foo", Foo).as(A::Info)
      A::Info.read("a.foo").as(A::Info)
      EOS
  end

  it "generates read and write methods on array" do
    assert_code <<-EOS
      struct A; end

      @[Chem::RegisterFormat(ext: %w(.foo))]
      module Foo
        def self.read(io : IO | Path | String) : A
          A.new
        end
        def self.read_all(io : IO | Path | String) : Array(A)
          [A.new]
        end
        def self.write(io : IO | Path | String, obj : A) : Nil
        end
        def self.write(io : IO | Path | String, objs : Enumerable(A)) : Nil
        end
      end

      Array(A).from_foo(IO::Memory.new).as(Array(A))
      Array(A).from_foo("a.foo").as(Array(A))
      Array(A).read(IO::Memory.new, Foo).as(Array(A))
      Array(A).read("a.foo", Foo).as(Array(A))
      Array(A).read("a.foo").as(Array(A))
      Array(A).new.to_foo
      Array(A).new.to_foo("a.foo")
      Array(A).new.write(IO::Memory.new, Foo)
      Array(A).new.write("a.foo", Foo)
      Array(A).new.write("a.foo")
      EOS
  end

  it "does not generate read methods on array for single-entry formats" do
    assert_error <<-EOS, "undefined method 'from_foo' for Array(A).class"
      struct A; end

      @[Chem::RegisterFormat(ext: %w(.foo))]
      module Foo
        def self.read(io : IO | Path | String) : A
          A.new
        end
      end

      Array(A).from_foo(IO::Memory.new)
      EOS
  end

  it "raises on incorrect array type" do
    message = "undefined method '.from_foo' for Array(Int32).class"
    assert_error <<-EOS, message
      struct A; end

      @[Chem::RegisterFormat(ext: %w(.foo))]
      module Foo
        def self.read(io : IO | Path | String) : A
          A.new
        end
        def self.read_all(io : IO | Path | String) : Array(A)
          [A.new]
        end
      end

      Array(Int32).from_foo(IO::Memory.new)
      EOS
  end

  it "works on union types (write only)" do
    assert_code <<-EOS
      struct A; end
      struct B; end

      @[Chem::RegisterFormat(ext: %w(.foo))]
      module Foo
        def self.write(io : IO | Path | String, obj : A | B) : Nil
        end
      end

      A.new.to_foo.as(String)
      B.new.to_foo.as(String)
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
        Array(Chem::Structure).read(IO::Memory.new, Chem::VASP::Poscar)
      end
    end

    it "raises if format does not decode the given type" do
      expect_raises ArgumentError, "DX format cannot read Array(Chem::Structure)" do
        Array(Chem::Structure).read(IO::Memory.new, Chem::DX)
      end
    end

    it "fails for non-encoded types", tags: %w(codegen) do
      assert_error "Array(Int32).read(IO::Memory.new, Chem::XYZ)",
        "undefined method 'read' for Array(Int32).class"
    end

    it "fails with an array for a single-entry type", tags: %w(codegen) do
      assert_error "Array(Chem::Spatial::Grid).read IO::Memory.new, Chem::XYZ",
        "undefined method 'read' for Array(Chem::Spatial::Grid).class"
    end
  end

  describe "#write" do
    it "writes in a multiple-entry format" do
      x = Array(Chem::Structure).from_pdb spec_file("models.pdb")
      String.build { |io| x.write(io, Chem::XYZ) }.should eq <<-XYZ
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
        Array(Chem::Structure).new.write(IO::Memory.new, Chem::VASP::Poscar)
      end
    end

    it "fails for non-encoded types", tags: %w(codegen) do
      assert_error "[1].write(IO::Memory.new, Chem::XYZ)",
        "undefined method 'write' for Array(Int32)"
    end

    it "fails with an array for a single-entry type", tags: %w(codegen) do
      assert_error "Array(Chem::Spatial::Grid).new.write IO::Memory.new, Chem::XYZ",
        "undefined method 'write' for Array(Chem::Spatial::Grid)"
    end
  end
end
