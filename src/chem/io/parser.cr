module Chem::IO
  abstract class Parser
    abstract def each_structure(&block : Structure ->)
    abstract def each_structure(indexes : Indexable(Int), &block : Structure ->)
    abstract def parse : Structure

    def initialize(@io : ::IO)
    end

    def initialize(content : String)
      @io = ::IO::Memory.new content
    end

    def initialize(path : Path)
      @io = ::IO::Memory.new File.read(path)
    end

    def eof? : Bool
      if bytes = @io.peek
        bytes.empty?
      else
        true
      end
    end

    def parse(index : Int) : Structure
      parse([index]).first
    end

    def parse(indexes : Array(Int)) : Array(Structure)
      ary = [] of Structure
      each_structure(indexes) { |structure| ary << structure }
      ary
    end

    def parse_all : Array(Structure)
      ary = [] of Structure
      each_structure { |structure| ary << structure }
      ary
    end

    def parse_exception(msg : String)
      raise ParseException.new msg
    end
  end

  module ParserWithLocation
    @prev_pos : Int32 | Int64 = 0

    def parse_exception(msg : String)
      loc, lines = guess_location
      raise ParseException.new msg, loc, lines
    end

    private def guess_location(nlines : Int = 3) : {Location, Array(String)}
      current_pos = @io.pos.to_i
      line_number = 0
      column_number = current_pos
      lines = Array(String).new nlines
      @io.rewind
      @io.each_line(chomp: false) do |line|
        line_number += 1
        lines.shift if lines.size == nlines
        lines << line.chomp
        break if @io.pos >= current_pos
        column_number -= line.size
      end
      @io.pos = current_pos

      size = current_pos - @prev_pos
      {Location.new(line_number, column_number - size + 1, size), lines}
    end

    private def read(& : -> T) : T forall T
      current_pos = @io.pos
      value = yield
      @prev_pos = current_pos
      value
    end
  end
end
