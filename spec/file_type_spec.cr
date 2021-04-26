require "./spec_helper"

describe Chem::FileType do
  it "checks for reader/writer" do
    assert_error <<-EOS, "Chem::Foo does not declare a Reader nor Writer type"
      @[Chem::FileType]
      module Chem::Foo; end
      EOS
  end

  it "checks for missing encoded types" do
    assert_error <<-EOS, "Chem::Foo does not declare readers or writers"
      @[Chem::FileType]
      module Chem::Foo
        class Reader; end
      end
      EOS
  end

  it "checks for duplicate file formats" do
    message = "Chem::Bar::Foo declares file format Foo, but it is already \
               declared by Chem::Foo"
    assert_error <<-EOS, message
      @[Chem::FileType]
      module Chem::Foo
        class Reader
          include Chem::FormatReader(Int32)
        end
      end

      @[Chem::FileType]
      module Chem::Bar::Foo
        class Reader
          include Chem::FormatReader(Int32)
        end
      end
      EOS
  end

  it "checks for duplicate file extensions" do
    message = ".log extension declared in FileType annotation for Chem::Bar is \
               already associated with file format Foo via Chem::Foo"
    assert_error <<-EOS, message
      @[Chem::FileType(ext: %w(log))]
      module Chem::Foo
        class Reader
          include Chem::FormatReader(String)
        end
      end

      @[Chem::FileType(ext: %w(log))]
      module Chem::Bar
        class Reader
          include Chem::FormatReader(String)
        end
      end
      EOS
  end

  it "checks for duplicate file name" do
    message = "Filename FOO* declared in FileType annotation for Chem::Bar is \
               already associated with file format Foo via Chem::Foo"
    assert_error <<-EOS, message
      @[Chem::FileType(names: %w(FOO))]
      module Chem::Foo
        class Reader
          include Chem::FormatReader(String)
        end
      end

      @[Chem::FileType(names: %w(FOO*))]
      module Chem::Bar
        class Reader
          include Chem::FormatReader(String)
        end
      end
      EOS
  end
end
