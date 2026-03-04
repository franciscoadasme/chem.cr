require "log"
require "views"

module Chem
  alias AtomContainer = AtomView | Residue | ResidueView | Chain | ChainView | Structure

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

  # Identifier for a residue in a structure.
  alias ResidueId = Tuple(Char, Int32, Char?)
end

# Creates a file overload for the given methods that receive a filepath (`Path | String`) instead of an IO as first argument.
# The generated method opens the file before calling the original method.
# Additional arguments are forwarded to the original method.
#
# Passed methods can include arguments to select which overload to use, otherwise all overloads with the same method name are included.
#
# Example:
#
# ```
# module Foo
#   def self.read(io : IO, arg1 : T, arg2 : U) : V; end
#   def self.read(io : IO, arg3 : T, arg4 : U) : V; end
#   def self.read(io : IO, arg5 : T, arg6 : U, arg7 : W) : V; end
#   def self.read_all(io : IO, arg1 : T, arg2 : U) : Array(V); end
#   def self.read_info(io : IO, arg1 : T, arg2 : U) : X; end
#   def self.read_info(io : IO, arg3 : T, arg4 : U) : X; end
#   define_file_overload(Foo, read, read_all, read_info(io, arg3, arg4))`
#   def self.write(io : IO, arg1 : T, arg2 : U) : Nil; end
#   define_file_overload(Foo, write, mode: "w")`
# end
# ```
#
# Generates:
#
# ```
# # file overloads are generated for all three read methods
# def self.read(path : Path | String, arg1 : T, arg2 : U) : V
#   File.open(path) { |file| read(file, arg1, arg2) }
# end
#
# def self.read(path : Path | String, arg3 : T, arg4 : U, arg5 : W) : V
#   File.open(path) { |file| read(file, arg3, arg4, arg5) }
# end
#
# def self.read(path : Path | String, arg5 : T, arg6 : U, arg7 : W) : V
#   File.open(path) { |file| read(file, arg5, arg6, arg7) }
# end
#
# def self.read_all(path : Path | String, arg1 : T, arg2 : U) : Array(V)
#   File.open(path) { |file| read_all(file, arg1, arg2) }
# end
#
# # only one file overload is generated for read_info
# def self.read_info(path : Path | String, arg3 : T, arg4 : U) : X
#   File.open(path) { |file| read_info(file, arg3, arg4) }
# end
#
# def self.write(path : Path | String, arg1 : T, arg2 : U) : Nil
#   File.open(path, mode: "w") { |file| write(file, arg1, arg2) }
# end
# ```
#
# NOTE: Must be called with a type name (not `self`).
macro define_file_overload(type, *calls, mode = "r")
  {% for call in calls %}
    {%
      methods = type.resolve.class.methods.select do |m|
        matches = m.name.id == call.name.id &&
                  m.args.size > 0 &&
                  m.args[0].restriction &&
                  m.args[0].restriction.stringify.includes?("IO")
        matches &&= m.args.map(&.name) == call.args.map(&.name) if call.args.size > 0
        matches
      end
      raise "Could not find #{type}.#{call}#{"(io, ...)".id unless call.args.size > 0}" unless methods.size > 0
    %}
    {% for method in methods %}
      {% args = method.args[1..] %}
      {% block_args = (1..method.block_arg.restriction.inputs.size).map { |i| "arg#{i}".id } if method.block_arg %}
      # {{ method.doc_comment.gsub(/\*io\*/, "*path*") }}
      def self.{{method.name.id}}(path : Path | String{% if args.size > 0 %}, {{args.splat}}{% end %}{% if method.block_arg %}, & {{method.block_arg}}{% end %}){% if method.return_type %} : {{method.return_type}}{% end %}
        File.open(path, mode: {{mode}}) do |file|
          {{method.name.id}}(file{% for arg in args %}, {{arg.internal_name.id}}{% end %}){% if method.block_arg %} do |{{block_args.splat}}|
          yield {{block_args.splat}}
          end {% end %}
        end
      end
    {% end %}
  {% end %}
end

require "./chem/core_ext/**"

require "./chem/metadata"
require "./chem/spatial"

require "./chem/core/residue"
require "./chem/core/atom"
require "./chem/connectivity"
require "./chem/core/bias"
require "./chem/core/bond_array"
require "./chem/core/element"
require "./chem/core/periodic_table"
require "./chem/core/chain"
require "./chem/core/atom_view"
require "./chem/core/residue_view"
require "./chem/core/chain_view"
require "./chem/core/structure"
require "./chem/core/structure/*"

require "./chem/templates"

require "./chem/protein"

require "./chem/pull_parser"
require "./chem/register_format"
require "./chem/format_reader"
require "./chem/format_writer"
require "./chem/formats/**"
