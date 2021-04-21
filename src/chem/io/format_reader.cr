module Chem
  # Declares the interface to implement for reading an object encoded in
  # a file format.
  #
  # Including types must implement a `#read(type : T.class) : T` method,
  # where the type variable `T` indicates the encoded type. Thus, a
  # reader class may decode multiple types by providing `#read`
  # overloads. This is useful for file formats that encode multiple
  # types in the same file, e.g., file formats for volumetric data in
  # computational chemistry may have a header encoding the underlying
  # molecular structure.
  #
  # Readers have access to the underlying IO through the `@io` instance
  # variable. Upon parsing issues, readers are expected to raise a
  # `ParseException` exception.
  #
  # Use the `Assignable.needs` macro to declare reading options, which
  # will be included as arguments in the `initialize` method that is
  # generated on compilation time in the concrete class via the
  # `IO::Wrapper` mixin.
  #
  # ```
  # class NumberReader
  #   include IO::FormatReader(Int32)
  #   include IO::FormatReader(Float64)
  #
  #   def read(type : Int32.class) : Int32
  #     @io.gets.to_i
  #   end
  #
  #   def read(type : Float64.class) : Float64
  #     @io.gets.to_f
  #   end
  # end
  #
  # io = IO::Memory.new "123\n456.78\n"
  # NumberReader.open(io) do |reader|
  #   reader.read(Int32)   # => 123
  #   reader.read(Float64) # => 456.78
  #   reader.read(Int32)   # raises EOFError
  #   io.rewind
  #   reader.read(Int32) # => 123
  #   reader.read(Int32) # raise ParseException
  # end
  # ```
  #
  # Modules declaring a reader class may be marked by the `FileType`
  # annotation to trigger automated read method generation for encoded
  # types.
  module IO::FormatReader(T)
    include ::IO::Wrapper

    # Reads the encoded object of type `T` from the IO. Raises
    # `ParseException` if an object couldn't be read or `EOFError` when
    # at the end of file.
    #
    # NOTE: After reading the object, it should not be read again as the
    # state of the underlying IO and reader could be changed and they
    # may not be reversible.
    abstract def read(type : T.class) : T

    @io : ::IO

    # Shorthand method for raising a `ParseException` exception.
    protected def parse_exception(msg : String)
      raise ParseException.new msg
    end

    # Raises an `IO::EOFError` if the underlying IO is at the end.
    protected def check_eof
      raise ::IO::EOFError.new if @io.peek.nil?
    end
  end

  # The `TextFormatReader` mixin changes the underlying IO to be a
  # `IO::Text` instance. The latter provides several convenience methods
  # from reading from a plain text file format.
  module IO::TextFormatReader(T)
    @io : ::IO::Text

    macro included
      macro finished
        \{% assigns = (ASSIGNABLES[@type] || [] of TypeDeclaration).sort_by do |decl|
             has_explicit_value =
               decl.type.is_a?(Metaclass) ||
                 decl.type.types.map(&.id).includes?(Nil.id) ||
                 decl.value ||
                 decl.value == nil ||
                 decl.value == false
             has_explicit_value ? 1 : 0
           end %}

        def initialize(
          io : ::IO,
          \{% for decl in assigns %}
            @\{{decl}},
          \{% end %}
          @sync_close : Bool = false,
        )
          @io = ::IO::Text.new io
        end
      end
    end

    # Raises an `IO::EOFError` if the underlying IO is at the end.
    #
    # Note that all whitespace is skipped over before checking for end
    # of file. Set *skip_lines* to `false` to skip spaces in the current
    # line only.
    protected def check_eof(skip_lines : Bool = true)
      if skip_lines
        @io.skip_whitespace
      else
        @io.skip_spaces
      end
      raise ::IO::EOFError.new if @io.eof?
    end
  end

  # The `MultiFormatReader` mixin provides an interface for a file
  # format that encodes a variable number of objects.
  #
  # Including types must provide the `#read_next` and `#skip` methods to
  # read and discard an entry in the IO, respectively.
  module IO::MultiFormatReader(T)
    # Returns the next entry in the IO, or `nil` if there are no more
    # entries. Raises `ParseException` if an object couldn't be read.
    #
    # NOTE: After reading an entry, previous entries can no longer be
    # read as the state of the underlying IO and reader could be changed
    # and they may not be reversible.
    abstract def read_next : T?

    # Discards the next entry in the IO. This method is expected to skip
    # an entry without fully parsing it.
    #
    # Calling this method when there are no more entries should not
    # fail.
    abstract def skip : Nil

    # Yields each entry in the IO to the given block.
    def each(& : T ->)
      while ele = read_next
        yield ele
      end
    end

    # Yields each entry in the IO at the specified *indexes* to the
    # given block. Raises `IndexError` when an index is out of bounds.
    def each(indexes : Enumerable(Int), & : T ->)
      (indexes.max + 1).times do |i|
        if i.in?(indexes)
          ele = read_next
          raise IndexError.new unless ele
          yield ele
        else
          skip
        end
      end
    end

    # Reads the next entry of type `T` from the IO. Raises
    # `ParseException` if an object couldn't be read or `EOFError` when
    # there are no more entries.
    #
    # NOTE: After reading an entry, previous entries can no longer be
    # read as the state of the underlying IO and reader could be changed
    # and they may not be reversible.
    def read(type : T.class) : T
      read_next || raise ::IO::EOFError.new
    end
  end
end
