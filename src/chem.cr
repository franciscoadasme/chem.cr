require "views"
require "./chem/core_ext/**"

require "./chem/spatial"

require "./chem/core/atom_collection"
require "./chem/core/residue"
require "./chem/core/atom"
require "./chem/connectivity"
require "./chem/core/bias"
require "./chem/core/bond_array"
require "./chem/core/element"
require "./chem/core/periodic_table"
require "./chem/core/residue_collection"
require "./chem/core/chain"
require "./chem/core/chain_collection"
require "./chem/core/atom_view"
require "./chem/core/residue_view"
require "./chem/core/chain_view"
require "./chem/core/structure"
require "./chem/core/structure/*"

require "./chem/templates"

require "./chem/protein"
require "./chem/topology"

require "./chem/pull_parser"
require "./chem/register_format"
require "./chem/format"
require "./chem/format_reader"
require "./chem/format_writer"
require "./chem/formats/**"

require "log"

module Chem
  Log = ::Log.for("chem")

  # Base class for Chem errors.
  class Error < Exception; end

  # Exception thrown upon parsing issues. Primarly used by `PullParser`.
  #
  # It can hold the location of the issue found in a text document. Call
  # `#inspect_with_location` to print a human-friendly error showing
  # such information.
  #
  # ```
  # ex = ParseException.new(
  #   message: "Invalid letters",
  #   path: "path/to/file",
  #   line: "abc def 123456 ABC DEF",
  #   location: {247, 8, 6}
  # )
  # puts ex.inspect_with_location
  # ```
  #
  # Prints out:
  #
  # ```text
  # Found a parsing issue in path/to/file:
  #
  #  247 | abc def 123456 ABC DEF
  #                ^^^^^^
  # Error: Invalid letters
  # ```
  class ParseException < Error
    # Line (if any) where the issue was found.
    getter line : String?
    # Error location (if any). It is a triplet containing line number,
    # column number, and cursor size where the issue is located.
    getter location : Tuple(Int32, Int32, Int32)?
    # Path to file (if any) that produced the error.
    getter source_file : String?

    # Creates a new exception without location.
    def initialize(@message : String); end

    # Creates a new exception with location, which is a triplet
    # containing line number, column number (starting at zero), and
    # cursor size. The latter may be zero to represent the beginning
    # (column number = 0) or end of line.
    def initialize(@message : String,
                   @source_file : String?,
                   @line : String,
                   @location : Tuple(Int32, Int32, Int32))
    end

    # Returns a string representation of the error including the
    # location.
    def inspect_with_location : String
      String.build do |io|
        inspect_with_location io
      end
    end

    # Writes a string representation of the error including the location
    # to *io*.
    def inspect_with_location(io : IO) : Nil
      io << "Found a parsing issue"
      io << " in " << @source_file if @source_file
      io << ':' << '\n' << '\n'
      if location = @location
        line_number, column_number, cursor_size = location
        if cursor_size == 0
          column_number -= 1 if column_number == 0
          cursor_size = 1
        end
        io << ' ' << line_number << " | " << @line << '\n'
        (column_number + line_number.to_s.bytesize + 4).times { io << ' ' }
        cursor_size.times { io << '^' }
        io << '\n'
      end
      io << "Error: " << @message
      io.flush
    end
  end

  class Metadata
    # Union of possible metadata types.
    alias ValueType = Int32 | Float64 | String | Bool

    include Enumerable({String, ValueType})
    include Iterable({String, ValueType})

    # `Any` is a value wrapper to encapsulate all possible metadata
    # types (`ValueType`). It provides convenient `#as_*` cast methods.
    struct Any
      getter raw : ValueType

      # Creates a new `Any` instance by enclosing the given value.
      def initialize(@raw : ValueType)
      end

      def ==(rhs : self) : Bool
        @raw == rhs.raw
      end

      def ==(rhs) : Bool
        @raw == rhs
      end

      # Returns the enclosed value as a bool. Raises `TypeCastError` if
      # it's not a bool.
      def as_bool : Bool
        @raw.as(Bool)
      end

      # Returns the enclosed value as a bool. Returns `nil` if it's not a
      # bool.
      def as_bool? : Bool?
        @raw.as?(Bool)
      end

      # Returns the enclosed value as a float. Raises `TypeCastError` if
      # it's not a float.
      def as_f : Float64
        case raw = @raw
        when Int
          raw.to_f
        else
          raw.as(Float64)
        end
      end

      # Returns the enclosed value as float. Returns `nil` if it's not a
      # float.
      def as_f? : Float64?
        case raw = @raw
        when Int
          raw.to_f
        else
          raw.as?(Float64)
        end
      end

      # Returns the enclosed value as an integer. Raises `TypeCastError`
      # if it's not an integer.
      def as_i : Int32
        @raw.as(Int).to_i
      end

      # Returns the enclosed value as an integer. Returns `nil` if it's
      # not an integer.
      def as_i? : Int32?
        @raw.as?(Int).try &.to_i
      end

      # Returns the enclosed value as a string. Raises `TypeCastError` if
      # it's not a string.
      def as_s : String
        @raw.as(String)
      end

      # Returns the enclosed value as a string. Returns `nil` if it's not
      # a string.
      def as_s? : String?
        @raw.as?(String)
      end

      def inspect(io : IO) : Nil
        io << self.class.name << '(' << @raw << ')'
      end

      def to_s(io : IO) : Nil
        @raw.to_s io
      end
    end

    @data = Hash(String, Any).new

    # Returns the value for the given key. Raises `KeyError` if not
    # found.
    def [](key : String) : Any
      @data[key]
    end

    {% for type in ValueType.union_types %}
      # Sets the value of *key* to the given value.
      def []=(key : String, value : {{type}}) : {{type}}
        @data[key] = Any.new(value)
        value
      end
    {% end %}

    # Returns the value for the given key. Returns `nil` if not found.
    def []?(key : String) : Any?
      @data[key]?
    end

    def each(& : {String, Type} ->) : Nil
      @data.each do |keyvalue|
        yield keyvalue
      end
    end

    def each : Iterator({String, Type})
      @data.each
    end

    # Empties the `Metadata` and returns it.
    def clear : self
      @data.clear
    end

    # Deletes the key-value pair and returns the value. Returns `nil` if
    # *key* does not exist.
    def delete(key : String) : Any?
      @data.delete(key)
    end

    # Deletes the key-value pair and returns the value. Yields *key* and
    # returns the value returned by the given block if *key* does not
    # exist.
    def delete(key : String, & : String ->) : Any?
      @data.delete(key) { |key| yield key }
    end

    # Yields each key to the given block.
    #
    # The enumeration follows the order the keys were inserted.
    def each_key(& : String ->) : Nil
      @data.each_key { |key| yield key }
    end

    # Returns an iterator over the keys.
    def each_key : Iterator(String)
      @data.each_key
    end

    # Yields each value to the given block.
    #
    # The enumeration follows the order the keys were inserted.
    def each_value(& : Any ->) : Nil
      @data.each_value { |value| yield value }
    end

    # Returns an iterator over the values.
    def each_value : Iterator(Any)
      @data.each_value
    end

    # Returns `true` when the metadata contains no key-value pairs, else
    # `false`.
    def empty? : Bool
      @data.empty?
    end

    # Returns `true` when the metadata contains no key-value pairs, else
    # `false`.
    def fetch? : Bool
      @data.empty?
    end
  end
end
