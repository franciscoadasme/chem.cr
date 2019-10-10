require "./io/*"

module Chem::IO
  struct Location
    getter column_number : Int32
    getter line_number : Int32
    getter size : Int32
    getter source_file : String?

    def initialize(@line_number : Int32, @column_number : Int32, @size : Int32)
    end

    def initialize(@source_file : String,
                   @line_number : Int32,
                   @column_number : Int32,
                   @size : Int32)
    end
  end

  class ParseException < Exception
    getter loc : Location?

    def initialize(message : String,
                   @loc : Location? = nil,
                   @lines : Indexable(String)? = nil)
      super message
    end

    def to_s_with_location : String
      String.build do |io|
        to_s_with_location io
      end
    end

    def to_s_with_location(io : ::IO) : Nil
      if loc = @loc
        io << "In "
        if source_file = loc.source_file
          io << source_file << ':'
        else
          io << "line "
        end
        io << loc.line_number << ':' << loc.column_number << ':'
        if lines = @lines
          io << '\n' << '\n'
          indent = Math.log10(loc.line_number).to_i + 1
          lines.each_with_index do |line, i|
            decorate_line io, line, loc.line_number - (lines.size - i - 1), indent
          end
          # four additional chars in ' XXX | '
          error_indicator io, loc.column_number + indent + 4, loc.size
          io << "Error: " << message
        else
          io << ' ' << message
        end
      else
        io << message
      end
    end

    private def decorate_line(io : ::IO, line : String, line_number : Int, indent : Int)
      io.printf " %#{indent}d | %s\n", line_number, line
    end

    private def error_indicator(io : ::IO, offset : Int, size : Int)
      (offset - 1).times { io << ' ' }
      io << '^'
      (size - 1).times { io << '~' } if size > 0
      io.puts
    end
  end

  enum TextAlignment
    Left
    Right
  end
end
