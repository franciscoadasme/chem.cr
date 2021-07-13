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
  # encoded in a file format.
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
      check_open
      @header ||= decode_header
    end
  end

  abstract class Structure::Reader
    include FormatReader(Structure)
    include Iterator(Structure)

    abstract def skip_structure : Nil

    def initialize(io : IO,
                   @guess_topology : Bool = true,
                   @sync_close : Bool = false)
      @io = TextIO.new io
    end

    def each(indexes : Enumerable(Int), &block : Structure ->)
      (indexes.max + 1).times do |i|
        if i.in?(indexes)
          value = self.next
          raise IndexError.new if value.is_a?(Stop)
          yield value
        else
          skip_structure
        end
      end
    end

    def select(indexes : Enumerable(Int)) : Iterator(Structure)
      SelectByIndex(typeof(self)).new self, indexes
    end

    def skip(n : Int) : Iterator(Structure)
      raise ArgumentError.new "Negative size: #{n}" if n < 0
      SkipStructure(typeof(self)).new self, n
    end

    protected def decode_entry : Structure
      first? || parse_exception "Empty content"
    end

    # Specialized iterator that creates/parses only selected structures by using
    # `Parser#skip_structure`, which doesn't parse skipped structures
    private class SelectByIndex(T)
      include Iterator(Structure)

      @indexes : Array(Int32)

      def initialize(@parser : T, indexes : Enumerable(Int))
        @current = 0
        @indexes = indexes.map(&.to_i).sort!
      end

      def next : Structure | Stop
        return stop if @indexes.empty?
        (@indexes.shift - @current).times do
          @parser.skip_structure
          @current += 1
        end
        value = @parser.next
        raise IndexError.new if value.is_a?(Stop)
        @current += 1
        value
      end
    end

    # Specialized iterator that uses `Parser#skip_structure` to avoid creating/parsing
    # skipped structures
    private class SkipStructure(T)
      include Iterator(Structure)

      def initialize(@parser : T, @n : Int32)
      end

      def next : Structure | Stop
        while @n > 0
          @n -= 1
          @parser.skip_structure
        end
        @parser.next
      end
    end
  end

  abstract class Spatial::Grid::Reader
    include FormatReader(Spatial::Grid)

    abstract def info : Spatial::Grid::Info

    def initialize(io : IO, @sync_close : Bool = false)
      @io = TextIO.new io
    end
  end
end
