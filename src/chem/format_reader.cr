module Chem
  # Declares a common interface for reading an object encoded in a file
  # format.
  #
  # Including types must implement the `#decode_entry : T` protected
  # method, where the type variable `T` indicates the encoded type. Upon
  # parsing issues, including types are expected to raise a
  # `ParseException` exception.
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
  # class Foo::Reader
  #   include Chem::FormatReader(Foo)
  #
  #   def decode_entry : Foo
  #     Foo.new num: @io.read_line.to_i, str: @io.read_line
  #   end
  # end
  #
  # io = IO::Memory.new "123\nbar\n"
  # reader = Foo::Reader.new io
  # reader.read? # => false
  # obj = reader.read_entry
  # obj.num           # => 123
  # obj.str           # => "bar"
  # reader.read?      # => true
  # reader.read_entry # raises IO::Error (entry was already read)
  # reader.close
  # reader.read_entry # raises IO::Error (closed IO)
  # ```
  module FormatReader(T)
    include IO::Wrapper

    # Returns `true` if this encoded object was already read.
    getter? read : Bool = false

    # Returns the encoded object. Raises `ParseException` if the object
    # cannot be decoded.
    #
    # NOTE: never invoke this method directly, use `#read_entry`
    # instead.
    protected abstract def decode_entry : T

    # Reads the encoded object of type `T` from the IO. Raises
    # `IO::Error` if the reader is closed or the encoded object has been
    # already read, or `ParseException` if an object cannot be read.
    def read_entry : T
      check_open
      check_read
      obj = decode_entry
      @read = true
      obj
    end

    # Raises an `IO::Error` if the entry was already read.
    protected def check_read
      raise IO::Error.new "Entry already read" if read?
    end

    # Shorthand method for raising a `ParseException` exception.
    protected def parse_exception(msg : String)
      raise ParseException.new msg
    end
  end

  # Declares a common interface for reading the header information
  # encoded in a file format. This is useful for cases when a file
  # format includes useful information (by itself) in the header.
  #
  # Including types must implement the `#decode_header : T` protected
  # method, where the type variable `T` indicates the header type. Upon
  # parsing issues, including types are expected to raise a
  # `ParseException` exception.
  module FormatReader::Headed(T)
    @header : T?

    # Returns the header object. Raises `ParseException` if the header
    # cannot be decoded.
    #
    # NOTE: never invoke this method directly, use `#read_header`
    # instead.
    protected abstract def decode_header : T

    # Reads the header object from the IO. Raises `IO::Error` if the
    # reader is closed or `ParseException` if the header cannot be
    # decoded.
    def read_header : T
      @header ||= begin
        check_open
        decode_header
      end
    end
  end

  # Declares a common interface for reading the attached object encoded
  # in a file format. This is useful for cases when a file format also
  # encode an additional object but it is not part of the main content
  # (e.g., some volumetric data file formats used in computational
  # chemistry also include information of the molecule structure).
  #
  # Including types must implement the `#decode_attached : T` protected
  # method, where the type variable `T` indicates the attached object
  # type. Upon parsing issues, including types are expected to raise a
  # `ParseException` exception.
  module FormatReader::Attached(T)
    @attached : T?

    # Returns the attached object. Raises `ParseException` if the object
    # cannot be decoded.
    #
    # NOTE: never invoke this method directly, use `#read_attached`
    # instead.
    protected abstract def decode_attached : T

    # Reads the attached object from the IO. Raises `IO::Error` if the
    # reader is closed or `ParseException` if the object cannot be
    # decoded.
    def read_attached : T
      @attached ||= begin
        check_open
        decode_attached
      end
    end
  end

  # Declares a common interface for reading a variable number of objects
  # encoded in a file format.
  #
  # Including types must implement the `#skip_entry` method to discard
  # the next entry in the IO.
  module FormatReader::MultiEntry(T)
    # Discards the next entry in the IO without fully parsing it.
    abstract def skip_entry : Nil

    # Yields each entry in the IO to the given block.
    def each(& : T ->) : Nil
      while obj = next_entry
        yield obj
      end
    end

    # Yields entries at the specified *indexes* in the IO to the given
    # block. Raises `IndexError` when an index is out of bounds.
    def each(indexes : Enumerable(Int), & : T ->)
      prev_i = -1
      indexes.each do |i|
        (i - prev_i - 1).times { skip_entry }
        obj = next_entry
        raise IndexError.new unless obj
        yield obj
        prev_i = i
      end
    end

    # Returns the next entry in the IO, or `nil` if there are no more
    # entries.
    def next_entry : T?
      check_open
      obj = decode_entry
      @read = true
      obj
    rescue IO::EOFError
      nil
    end

    # Returns the next entry in the IO. Raises `ParseException` if there
    # are no more entries.
    def read_entry : T
      next_entry || parse_exception (@read ? "No more entries" : "Empty content")
    end

    def to_a : Array(T)
      ary = [] of T
      each { |ele| ary << ele }
      ary
    end
  end
end
