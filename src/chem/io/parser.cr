module Chem
  module IO
    abstract class Parser(T)
      abstract def parse : T

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

    module PullParser
      include ParserWithLocation

      def check(& : Char -> Bool) : Bool
        return false unless char = peek?
        yield char
      end

      def check(char : Char) : Bool
        peek? == char
      end

      def check(string : String) : Bool
        peek?(string.size) == string
      end

      def check_in_set(charset : String) : Bool
        check &.in_set?(charset)
      end

      def peek : Char
        peek? || raise ::IO::EOFError.new
      end

      def peek(count : Int) : String
        peek?(count) || raise ::IO::EOFError.new
      end

      def peek_line : String
        peek_line? || raise ::IO::EOFError.new
      end

      def peek_line? : String?
        peek { @io.gets }
      end

      def peek? : Char?
        peek { read? }
      end

      def peek?(count : Int) : String?
        peek { read? count }
      end

      def prev_char : Char
        parse_exception "Couldn't read previous character" if @io.pos == 0
        @io.pos -= 1
        read
      end

      def read : Char
        read? || raise ::IO::EOFError.new
      end

      def read(count : Int) : String
        read { @io.read_string count }
      end

      def read? : Char?
        read { @io.read_char }
      end

      def read?(count : Int) : String?
        read count
      rescue ::IO::EOFError
        nil
      end

      def read_float : Float64
        read do
          skip_whitespace
          String.build do |io|
            io << read_sign
            read_digits io
            if check '.'
              io << read
              read_digits io
            end
            if char = read_in_set("eE")
              io << char
              io << read_sign
              read_digits io
            end
          end
        end.to_f
      rescue ArgumentError
        parse_exception "Couldn't read a decimal number"
      end

      def read_float(count : Int) : Float64
        read(count).to_f
      rescue ArgumentError
        parse_exception "Couldn't read a decimal number"
      end

      def read_int : Int32
        read do
          skip_whitespace
          String.build do |io|
            io << read_sign
            read_digits io
          end
        end.to_i
      rescue ArgumentError
        parse_exception "Couldn't read a number"
      end

      def read_int(count : Int) : Int32
        read(count).to_i
      rescue ArgumentError
        parse_exception "Couldn't read a number"
      end

      def read_in_set(charset : String) : Char?
        read? if check_in_set charset
      end

      def read_line : String
        read_line? || raise ::IO::EOFError.new
      end

      def read_line? : String?
        read { @io.gets }
      end

      def read_vector : Spatial::Vector
        Spatial::Vector.new read_float, read_float, read_float
      end

      def rewind(&block : Char -> Bool) : self
        while char = prev_char
          break unless yield char
          @io.pos -= 1
        end
        self
      rescue ParseException
        self
      end

      def scan(pattern : Regex) : String
        String.build do |io|
          scan io, pattern
        end
      end

      def scan(io : ::IO, pattern : Regex) : self
        scan(io) do |char|
          !pattern.match(char.to_s).nil?
        end
      end

      # FIXME: raise an exception instead of return "" if cannot read anymore?
      def scan(& : Char -> Bool) : String
        String.build do |io|
          scan(io) do |char|
            yield char
          end
        end
      end

      def scan(io : ::IO, & : Char -> Bool) : self
        read do
          prev_pos = @io.pos
          while char = read?
            break unless yield char
            io << char
            prev_pos = @io.pos
          end
          @io.pos = prev_pos
        end
        self
      end

      def scan_delimited(& : Char -> Bool) : Array(String)
        Array(String).new.tap do |ary|
          loop do
            skip_whitespace
            value = scan { |char| yield char }
            break if value.empty?
            ary << value
          end
        end
      end

      def scan_delimited(delimiter : Char, & : Char -> Bool) : Array(String)
        Array(String).new.tap do |ary|
          loop do
            skip delimiter, limit: 1
            value = scan { |char| yield char }
            break if value.empty? && peek? != delimiter
            ary << value
          end
        end
      end

      def scan_delimited_by_set(charset : String, & : Char -> Bool) : Array(String)
        Array(String).new.tap do |ary|
          loop do
            skip_in_set charset
            value = scan { |char| yield char }
            break if value.empty?
            ary << value
          end
        end
      end

      def scan_in_set(charset : String) : String
        scan &.in_set?(charset)
      end

      def scan_until(pattern : Regex) : String
        scan do |char|
          pattern.match(char.to_s).nil?
        end
      end

      def skip : self
        read?
        self
      end

      def skip(& : Char -> Bool) : self
        read do
          prev_pos = @io.pos
          while char = read?
            break unless yield char
            prev_pos = @io.pos
          end
          @io.pos = prev_pos
        end
        self
      end

      def skip(count : Int) : self
        read { @io.gets count }
        self
      end

      def skip(limit count : Int, & : Char -> Bool) : self
        skip do |char|
          (count -= 1) >= 0 ? yield char : false
        end
      end

      def skip(char : Char) : self
        skip &.==(char)
      end

      def skip(char : Char, limit : Int) : self
        skip limit, &.==(char)
      end

      def skip(pattern : Regex) : self
        skip { |char| !pattern.match(char.to_s).nil? }
      end

      def skip_in_set(charset : String) : self
        skip &.in_set?(charset)
      end

      def skip_line : self
        read { @io.gets }
        self
      end

      def skip_spaces : self
        skip_in_set " \t"
      end

      def skip_whitespace : self
        skip &.ascii_whitespace?
      end

      private def peek(& : -> T) : T forall T
        prev_pos = @io.pos
        value = yield
        @io.pos = prev_pos
        value
      end

      private def read_digits(io : ::IO) : self
        scan(io) { |chr| '0' <= chr <= '9' }
        self
      end

      private def read_sign : Char?
        read_in_set "+-"
      end
    end

    module ColumnBasedParser
      @line = ""
      @line_number = 0
      @cursor = 0..0

      abstract def current_record : String

      def each_record(& : String ->) : Nil
        loop do
          yield current_record
          break unless next_record
        end
      end

      def each_record_of(name : String, & : ->) : Nil
        each_record do |record_name|
          break unless record_name == name
          yield
        end
        back_to_beginning_of_line
      end

      def each_record_reversed(& : String ->) : Nil
        while @io.pos > 1
          @line = String.build do |io|
            loop do
              @io.pos -= 2
              break unless (ch = @io.read_char) && ch != '\n'
              io << ch
              break if @io.pos < 2
            end
          end.reverse
          @line_number -= 1
          @cursor = 0..0
          yield current_record
        end
      end

      def next_record : String?
        return unless line = @io.gets(chomp: false)
        @line = line
        @line_number += 1
        @cursor = 0..0
        current_record
      end

      def read(index : Int) : Char
        @cursor = index..index
        @line[index]
      end

      def read(range : Range(Int, Int)) : String
        @cursor = range
        @line[range]
      end

      def read(start : Int, count : Int) : String
        @cursor = start..(count - 1)
        @line[start, count]
      end

      def read?(index : Int) : Char?
        @cursor = index..index
        if char = @line[index]?
          char.whitespace? ? nil : char
        end
      end

      def read?(range : Range(Int, Int)) : String?
        @cursor = range
        if str = @line[range]?
          str.blank? ? nil : str
        end
      end

      def read?(start : Int, count : Int) : String?
        @cursor = start..(count - 1)
        if str = @line[start, count]?
          str.blank? ? nil : str
        end
      end

      def read_float(range : Range(Int, Int)) : Float64
        read(range).to_f
      rescue ArgumentError
        parse_exception "Couldn't read a decimal number"
      end

      def read_float(start : Int, count : Int) : Float64
        read(start, count).to_f
      rescue ArgumentError
        parse_exception "Couldn't read a decimal number"
      end

      def read_float?(range : Range(Int, Int)) : Float64?
        read?(range).try &.to_f
      end

      def read_float?(start : Int, count : Int) : Float64?
        read?(start, count).try &.to_f
      end

      def read_int(range : Range(Int, Int)) : Int32
        read(range).to_i
      rescue ArgumentError
        parse_exception "Couldn't read an integer"
      end

      def read_int(start : Int, count : Int) : Int32
        read(start, count).to_i
      rescue ArgumentError
        parse_exception "Couldn't read an integer"
      end

      def read_int?(range : Range(Int, Int)) : Int32?
        read?(range).try &.to_i
      end

      def read_int?(start : Int, count : Int) : Int32?
        read?(start, count).try &.to_i
      end

      def skip_until(name : String) : Nil
        each_record do |record_name|
          break if record_name == name
        end
      end

      private def back_to_beginning_of_line : Nil
        @io.pos -= @line.bytesize
      end

      private def read_context(& : ->) : Nil
        prev_pos = @io.pos
        prev_line = @line
        prev_line_number = @line_number
        yield
        @io.pos = prev_pos
        @line = prev_line
        @line_number = prev_line_number
      end
    end

    module AsciiParser
      @buffer = Bytes.new 8192
      @bytes_read = -1
      @pos = 0

      def current_char : Char
        @buffer.unsafe_fetch(@pos).unsafe_chr
      end

      def eof? : Bool
        @bytes_read == 0 # no more bytes to read at eof
      end

      def peek : Char?
        char = read
        @pos -= 1 if char
        char
      end

      def read : Char?
        read_raw if eob?
        return if eof?
        chr = current_char
        @pos += 1
        chr
      end

      def read_float : Float64
        read_float? || parse_exception "Couldn't read a decimal number"
      end

      def read_float? : Float64?
        return if eof?

        if bytes = next_non_whitespace
          value = LibC.strtod bytes.to_unsafe, out endptr
          return value if endptr == bytes.to_unsafe + bytes.size
        end
      end

      def read_vector : Spatial::Vector
        Spatial::Vector.new read_float, read_float, read_float
      end

      def read_word : String
        read_word? || raise ::IO::EOFError.new
      end

      def read_word? : String?
        if bytes = next_non_whitespace
          String.new bytes
        end
      end

      def skip_line : Nil
        while (chr = read) && chr != '\n'
        end
      end

      def skip_word : Nil
        next_non_whitespace
      end

      def skip_words(n : Int) : Nil
        n.times { next_non_whitespace }
      end

      private def eob? : Bool
        @pos >= @bytes_read || @bytes_read < 0
      end

      private def next_non_whitespace : Bytes?
        start = -1
        loop do
          if eof?
            return nil
          elsif eob?
            if start >= 0
              bytesize = @pos - start
              @buffer.copy_from @buffer.to_unsafe + start, bytesize
              read_raw offset: bytesize
              start = 0
            else
              read_raw
              start = -1
            end
          end

          if current_char.whitespace?
            return Bytes.new(@buffer.to_unsafe + start, @pos - start) if start >= 0
          elsif start < 0
            start = @pos
          end

          @pos += 1
        end
      end

      private def read_raw(offset : Int = 0)
        @bytes_read = @io.read(@buffer + offset) + offset
        @pos = offset
      end
    end
  end

  abstract class Structure::Parser < IO::Parser(Structure)
    include Iterator(Structure)

    abstract def skip_structure : Nil

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

    def parse : Structure
      first? || parse_exception "Empty content"
    end

    def select(indexes : Enumerable(Int)) : Iterator(Structure)
      SelectByIndex(typeof(self)).new self, indexes
    end

    def skip(n : Int) : Iterator(Structure)
      raise ArgumentError.new "Negative size: #{n}" if n < 0
      SkipStructure(typeof(self)).new self, n
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

  macro finished
    {% for parser in IO::Parser.all_subclasses.select(&.annotation(IO::FileType)) %}
      {% format = parser.annotation(IO::FileType)[:format].id.underscore %}

      {% type = parser.ancestors.reject(&.type_vars.empty?)[0].type_vars[0] %}
      {% keyword = type.class.id.ends_with?("Module") ? "module" : nil %}
      {% keyword = type < Reference ? "class" : "struct" unless keyword %}

      {{keyword.id}} ::{{type.id}}
        def self.from_{{format.id}}(input : ::IO | Path | String, **options) : self
          {{parser}}.new(input, **options).parse
        end
      end

      class ::Array(T)
        def self.from_{{format.id}}(input : ::IO | Path | String, **options) : self
          {{parser}}.new(input, **options).to_a
        end

        def self.from_{{format.id}}(input : ::IO | Path | String,
                                    indexes : Array(Int),
                                    **options) : self
          ary = Array(Chem::Structure).new indexes.size
          {{parser}}.new(input, **options).each(indexes) { |st| ary << st }
          ary
        end
      end
    {% end %}
  end
end
