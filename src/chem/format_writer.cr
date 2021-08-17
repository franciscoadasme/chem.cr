module Chem
  # Declares a common interface for writing an object encoded in a file
  # format.
  #
  # Including types must implement the `#encode_entry(T)` protected
  # method, where the type variable `T` indicates the encoded type.
  #
  # Including types will behave like an IO wrapper via the `IO::Wrapper`
  # mixin, which provides convenience constructors. Initialization
  # arguments are gathered from the designated `#initialize` method
  # looked up on concrete types at compilation time. The underlying IO
  # can be accessed through the `@io` instance variable.
  #
  # ```
  # struct Foo
  #   getter num : Int32
  #   getter str : String
  #
  #   def initialize(@num : Int32, @str : String); end
  # end
  #
  # class Foo::Writer
  #   include Chem::FormatWriter(Foo)
  #
  #   def encode_entry(foo : Foo) : Nil
  #     @io.puts foo.num
  #     @io.puts foo.str
  #   end
  # end
  #
  # io = IO::Memory.new
  # writer = Foo::Writer.new io
  # writer.written? # => false
  # writer << Foo.new(123, "bar")
  # io.to_s                       # => "123\nbar\n"
  # writer.written?               # => true
  # writer << Foo.new(456, "baz") # raises IO::Error (an entry was already written)
  # writer.close
  # writer << Foo.new(789, "foo") # raises IO::Error (closed IO)
  # ```
  module FormatWriter(T)
    include IO::Wrapper

    # Returns `true` if an object was already written.
    getter? written : Bool = false

    # File open mode. May be overriden by including types.
    FILE_MODE = "w"

    # Writes *obj* to the `IO`.
    #
    # NOTE: never invoke this method directly, use `#<<` instead.
    protected abstract def encode_entry(obj : T) : Nil

    def <<(obj : T) : Nil
      check_open
      check_write
      encode_entry obj
      @written = true
    end

    def format(str : String, *args, **options) : Nil
      @io.printf str, *args, **options
    end

    def formatl(str : String, *args, **options) : Nil
      format str, *args, **options
      @io << '\n'
    end

    # Raises an `IO::Error` if an entry was already written to the IO.
    protected def check_write
      raise IO::Error.new "An entry was already written to the IO" if written?
    end
  end

  # The `MultiEntry` mixin provides an interface for writing in a file
  # format that can hold a variable number of objects.
  #
  # It holds the total number of entries (`#total_entries`) and
  # reimplements the `<<` operator to track how many of them has been
  # written so far.
  module FormatWriter::MultiEntry(T)
    @entry_index = 0

    # Total number of entries to be written. A value of `nil` indicates
    # that it could not be determinate.
    @total_entries : Int32?

    # Creates a new object from the given *io*. If the number of entries
    # to be written is known, pass *total_entries*, otherwise set it to
    # `nil`.
    def initialize(@io : IO, @total_entries : Int32? = nil, @sync_close : Bool = false)
    end

    # Writes *obj* to the `IO`. It keeps count of the number of entries
    # written to the `IO`.
    def <<(obj : T) : self
      check_open
      encode_entry obj
      @entry_index += 1
      @written = true
      self
    end

    # Returns `true` if multiple entries or an indeterminate number of
    # entries are to be written, else `false`.
    def multi? : Bool
      (@total_entries || Int32::MAX) > 1
    end
  end
end
