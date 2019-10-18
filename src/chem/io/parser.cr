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
