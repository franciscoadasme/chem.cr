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

require "./chem/atom_template"
require "./chem/bond_type"
require "./chem/residue_template"
require "./chem/residue_template/*"

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
end
