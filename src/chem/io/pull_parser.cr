module Chem::IO
  module PullParser
    abstract def parse_exception(msg : String)

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
      peek { read_line }
    end

    def peek? : Char?
      peek { read_char? }
    end

    def peek?(count : Int) : String?
      peek { read_chars? count }
    end

    def prev_char : Char
      parse_exception "Couldn't read previous character" if @io.pos == 0
      @io.pos -= 1
      read_char
    end

    def read_char : Char
      read_char? || raise ::IO::EOFError.new
    end

    def read_char? : Char?
      @io.read_char
    end

    def read_char_in_set(charset : String) : Char?
      read_char if check_in_set charset
    end

    def read_char_or_null : Char?
      char = read_char
      char.whitespace? ? nil : char
    end

    def read_chars(*args, **options) : String
      read_chars?(*args, **options) || raise ::IO::EOFError.new
    end

    def read_chars?(count : Int) : String?
      @io.read_string count
    rescue ::IO::EOFError
      nil
    end

    def read_chars?(count : Int, stop_at sentinel : Char) : String?
      chars = read_chars? count
      if chars && (pos = chars.index sentinel)
        @io.pos -= chars.size - pos
        chars = chars[...pos]
      end
      chars
    end

    def read_chars_or_null(*args, **options) : String?
      chars = read_chars *args, **options
      chars.blank? ? nil : chars
    end

    # TODO add support for scientific notation
    def read_float : Float64
      skip_whitespace
      String.build do |io|
        io << read_sign
        read_digits io
        if check '.'
          io << read_char
          read_digits io
        end
        if char = read_char_in_set("eE")
          io << char
          io << read_sign
          read_digits io
        end
      end.to_f
    rescue ArgumentError
      parse_exception "Couldn't read a decimal number"
    end

    def read_float(count : Int32) : Float64
      read_chars(count).to_f
    rescue ArgumentError
      parse_exception "Couldn't read a decimal number"
    end

    def read_int : Int32
      skip_whitespace
      String.build do |io|
        io << read_sign
        read_digits io
      end.to_i
    rescue ArgumentError
      parse_exception "Couldn't read a number"
    end

    def read_int(count : Int32, **options) : Int32
      read_chars(count, **options).to_i
    rescue ArgumentError
      parse_exception "Couldn't read a number"
    end

    # TODO rename to `read_int` with option `on_blank`
    def read_int_or_null(count : Int32, **options) : Int32?
      chars = read_chars count, **options
      return nil if chars.blank?
      chars.to_i
    rescue ArgumentError
      parse_exception "Couldn't read a number"
    end

    def read_line : String
      @io.read_line
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
      prev_pos = @io.pos
      while char = read_char?
        break unless yield char
        io << char
        prev_pos = @io.pos
      end
      @io.pos = prev_pos
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
      read_char?
      self
    end

    def skip(& : Char -> Bool) : self
      prev_pos = @io.pos
      while char = read_char?
        break unless yield char
        prev_pos = @io.pos
      end
      @io.pos = prev_pos
      self
    end

    def skip(count : Int) : self
      count.times { skip }
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
      @io.gets
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
      read_char_in_set "+-"
    end
  end
end
