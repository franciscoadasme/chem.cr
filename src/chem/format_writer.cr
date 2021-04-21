module Chem
  # Declares the interface to implement for encoding an object in a file
  # format.
  #
  # Including types must implement a `#write(obj : T)` method, where the
  # type variable `T` indicates the encoded type. Thus, a writer class
  # may encode multiple types by providing `#write` overloads. This is
  # useful for file formats that encode multiple types in the same file,
  # e.g., file formats for volumetric data in computational chemistry
  # may have a header encoding the underlying molecular structure.
  #
  # Writers have access to the underlying IO through the `@io` instance
  # variable.
  #
  # Use the `Assignable.needs` macro to declare writing options, which
  # will be included as arguments in the `initialize` method that is
  # generated on compilation time in the concrete class via the
  # `IO::Wrapper` mixin.
  #
  # ```
  # class NumberWriter
  #   include FormatWriter(Int32)
  #
  #   needs format : String
  #
  #   def write(obj : Int32) : Nil
  #     formatl @format, obj
  #   end
  # end
  #
  # io = IO::Memory.new
  # NumberWriter.open(io, format: "%+8.3f") do |writer|
  #   writer.write 123
  #   writer.write 45678
  # end
  # io.to_s # => "    +123.000\n  -45678.000\n"
  # ```
  #
  # Modules declaring a writer class may be marked by the `FileType`
  # annotation to trigger automated write method generation for encoded
  # types.
  module FormatWriter(T)
    include IO::Wrapper

    # File open mode. May be overriden by including types.
    FILE_MODE = "w"

    # Writes *obj* to the `IO` encoded in the file format.
    abstract def write(obj : T) : Nil

    @io : IO

    # Writes a formatted string to the IO. For details on the format
    # string, see `sprintf`.
    def format(str : String, *args, **options) : Nil
      @io.printf str, *args, **options
    end

    # Writes a formatted string terminated in a newline to the IO. For
    # details on the format string, see `sprintf`.
    def formatl(str : String, *args, **options) : Nil
      format str, *args, **options
      @io << '\n'
    end
  end
end
