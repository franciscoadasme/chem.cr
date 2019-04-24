module Chem::IO
  module PullParser
    @input : ::IO

    abstract def parse

    macro included
      private def parse_exception(msg : String)
        {% scope = @type.name.split("::")[0...-1].join "::" %}
        raise {{scope.id}}::ParseException.new msg
      end
    end

    def initialize(@input : ::IO)
    end

    def fail(msg : String)
      line_number, column_number = guess_location
      parse_exception "#{msg} at #{line_number}:#{column_number}"
    end

    def peek_char : Char
      peek { read_char }
    end

    def peek_chars(count : Int) : String
      peek { read_chars count }
    end

    def peek_line : String
      peek { read_line }
    end

    def prev_char : Char
      raise ParseException.new "Couldn't read previous character" if @input.pos == 0
      @input.pos -= 1
      read_char
    end

    def read_char : Char
      read_char? || raise ::IO::EOFError.new
    end

    def read_char? : Char?
      @input.read_char
    end

    def read_char_or_null : Char?
      char = read_char
      char.whitespace? ? nil : char
    end

    def read_chars(*args, **options) : String
      read_chars?(*args, **options) || raise ::IO::EOFError.new
    end

    def read_chars?(count : Int) : String?
      @input.read_string count
    rescue ::IO::EOFError
      nil
    end

    def read_chars?(count : Int, stop_at sentinel : Char) : String?
      chars = read_chars? count
      if chars && (pos = chars.index sentinel)
        @input.pos -= chars.size - pos
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
      scan(/[-\d\.]/, skip_leading_whitespace: true).to_f
    rescue ArgumentError
      fail "Couldn't read a decimal number"
    end

    def read_float(count : Int32) : Float64
      read_chars(count).to_f
    rescue ArgumentError
      fail "Couldn't read a decimal number"
    end

    def read_int(count : Int32, **options) : Int32
      read_chars(count, **options).to_i
    rescue ArgumentError
      fail "Couldn't read a number"
    end

    # TODO rename to `read_int` with option `on_blank`
    def read_int_or_null(count : Int32, **options) : Int32?
      chars = read_chars count, **options
      return nil if chars.blank?
      chars.to_i
    rescue ArgumentError
      fail "Couldn't read a number"
    end

    def read_line : String
      @input.read_line
    end

    def read_multiple_int : Array(Int32)
      scan_multiple(&.number?).map &.to_i
    end

    def rewind(&block : Char -> Bool) : self
      while char = prev_char
        break unless yield char
        @input.pos -= 1
      end
      self
    rescue ParseException
      self
    end

    def scan(pattern : Regex, skip_leading_whitespace : Bool = true) : String
      scan(skip_leading_whitespace) do |char|
        !pattern.match(char.to_s).nil?
      end
    end

    # TODO remove skip_leading_whitespace option
    # FIXME: raise an exception instead of return "" if cannot read anymore?
    def scan(skip_leading_whitespace : Bool = true, &block : Char -> Bool) : String
      prev_pos = @input.pos
      skip_whitespace if skip_leading_whitespace
      String.build do |io|
        while char = @input.read_char
          break unless yield char
          io << char
          prev_pos = @input.pos
        end
        @input.pos = prev_pos
      end
    end

    # TODO change to scan_delimited and add a delimiter : Char option
    def scan_multiple(&block : Char -> Bool) : Array(String)
      Array(String).new.tap do |ary|
        until (value = scan(&block)).empty?
          ary << value
        end
      end
    end

    def scan_until(pattern : Regex) : String
      scan(skip_leading_whitespace: false) do |char|
        pattern.match(char.to_s).nil?
      end
    end

    def skip(&block : Char -> Bool) : self
      prev_pos = @input.pos
      while char = @input.read_char
        break unless yield char
        prev_pos = @input.pos
      end
      @input.pos = prev_pos
      self
    end

    # TODO why? maybe delete?
    def skip(max_count : Int, &block : Char -> Bool) : self
      max_count += 1
      count = 0
      skip do |char|
        count += 1
        count != max_count && yield char
      end
    end

    def skip(pattern : Regex) : self
      skip { |char| !pattern.match(char.to_s).nil? }
    end

    def skip_char : self
      skip_chars 1
    end

    def skip_chars(count : Int) : self
      @input.skip count
      self
    end

    def skip_chars(count : Int, stop_at sentinel : Char) : self
      skip(count) { |char| char != sentinel }
    end

    def skip_line : self
      @input.read_line
      self
    end

    def skip_whitespace : self
      skip { |char| char.whitespace? }
    end

    private def guess_location : {Int32, Int32}
      prev_pos = @input.pos
      @input.rewind
      text = read_chars prev_pos
      {text.count('\n') + 1, text.size - (text.rindex('\n') || 0)}
    end

    private def peek
      prev_pos = @input.pos
      value = yield
      @input.pos = prev_pos
      value
    end
  end
end
