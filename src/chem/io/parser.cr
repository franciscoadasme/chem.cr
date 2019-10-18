module Chem::IO
  abstract class Parser
    include Iterator(Structure)

    def initialize(@io : ::IO)
    end

    def initialize(content : String)
      @io = ::IO::Memory.new content
    end

    def initialize(path : Path)
      @io = ::IO::Memory.new File.read(path)
    end

    def each(indexes : Enumerable(Int), &block : Structure ->)
      (indexes.max + 1).times do |i|
        if indexes.includes? i
          value = self.next
          raise IndexError.new if value.is_a?(Stop)
          yield value
        else
          skip_structure
        end
      end
    end

    def eof? : Bool
      if bytes = @io.peek
        bytes.empty?
      else
        true
      end
    end

    def parse_exception(msg : String)
      raise ParseException.new msg
    end

    def select(indexes : Enumerable(Int)) : Iterator(Structure)
      SelectByIndex(typeof(self)).new self, indexes
    end

    def skip(n : Int) : Iterator(Structure)
      raise ArgumentError.new "Negative size: #{n}" if n < 0
      SkipStructure(typeof(self)).new self, n
    end

    def skip_structure : Nil
      @io.skip_to_end
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
        puts typeof(value)
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

  macro finished
    class ::Array(T)
      {% for parser in Parser.subclasses.select(&.annotation(FileType)) %}
        {% format = parser.annotation(FileType)[:format].id.underscore %}

        def self.from_{{format.id}}(input : ::IO | Path | String, **options) : self
          \{% raise "Invalid use of `Array#from_{{format.id}}` with type #{T}" \
                unless T == Chem::Structure %}
          {{parser}}.new(input, **options).to_a
        end

        def self.from_{{format.id}}(input : ::IO | Path | String,
                                    indexes : Array(Int),
                                    **options) : self
          \{% raise "Invalid use of `Array#from_{{format.id}}` with type #{T}" \
                unless T == Chem::Structure %}
          ary = Array(Chem::Structure).new indexes.size
          {{parser}}.new(input, **options).each(indexes) { |st| ary << st }
          ary
        end
      {% end %}
    end
  end
end
