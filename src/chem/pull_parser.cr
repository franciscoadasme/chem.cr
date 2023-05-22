module Chem
  # A pull parser to read a text (ASCII) document by consuming one token
  # at a time.
  #
  # The parser reads line by line, which is set to an internal buffer.
  # Subsequent tokens (consecutive non-whitespace characters) can be
  # consumed via the `#next_token` method (although only from the
  # current line). The string representation of the current token can be
  # obtained via the `#str` methods or it can be interpreted as a
  # primitive type via the specialized  `#float` and `#int` methods. It
  # can be also interpreted as a custom type via the `#parse` method.
  # Upon parsing issues, these methods may return `nil` or raise a
  # `ParseException` exception.
  #
  # When creating an instance, the parser must be positioned in the
  # first line before consuming a token by calling `#next_line`, using
  # the yielding method `#each_line`, or checking for end of file via
  # `#eof?`. Upon reading a new line, the cursor is reset and the
  # current token is set to `nil`, so `#next_token` must be called
  # before parsing. If the current token is not set, the parsing methods
  # may return `nil` or raise an exception. Alternatively, use the
  # convenience `#next_f`, `#next_i`, or `#next_s` methods that consume
  # the next token and return the interpreted value.
  #
  # The `#next_*` methods always move forward into the IO or line, so
  # care must be taken when calling them as invoking `#next_s?` twice
  # will return the next two strings (if possible), not twice the same.
  # For instance, calling `#next_i?` after `#next_f?` returns `nil` will
  # read the next token instead of re-interpreting the current one as an
  # integer. In such cases, consider using the non-advancing methods
  # (`#int` instead of `#next_i`).
  #
  # Example:
  #
  # ```
  # pull = PullParser.new IO::Memory.new("abc def\n1234 5.6 abc\n")
  # pull.next_token.str?           # => nil (line not read)
  # pull.next_line                 # place the parser at the first line
  # pull.str?                      # => nil (current token is nil)
  # pull.next_s?                   # => "abc"
  # pull.str?                      # => "abc" (current token was set by #next_s?)
  # pull.next_s?                   # => "def"
  # pull.next_s?                   # => nil (end of line)
  # pull.next_s                    # raises ParseException (no token can be consumed)
  # pull.next_line                 # place the parser at the second line
  # pull.next_i                    # => 1234
  # pull.next_f                    # => 5.6
  # pull.next_token.str?           # => "abc"
  # pull.int?                      # => nil
  # pull.float?                    # => nil
  # pull.parse &.sum(&.+('a'.ord)) # => 3
  # pull.next_token.str?           # => nil (end of line)
  # pull.next_line                 # => nil (place the parser at the end of IO)
  # pull.next_token.str?           # => nil (current line is nil)
  # ```
  #
  # Additionally, the cursor can be manually placed on the current line
  # via the `#at` methods. This is useful for parsing fixed-column
  # formats such as `#PDB`. The non-question variants will raise if the
  # cursor is out of bounds.
  #
  # ```
  # pull = PullParser.new IO::Memory.new("abc123.45def\nABCDEF 5.16\n")
  # pull.next_line
  # pull.at(3, 6)     # returns the parser itself
  # pull.str          # => "123.45"
  # pull.float        # => 123.45
  # pull.at(9).str    # => "d"
  # pull.at(0, 3).str # => "abc"
  # pull.at(100, 5)   # raises ParseException
  # ```
  class PullParser
    @buffer : Bytes = Bytes.empty
    @line : String?
    @line_number = 0
    @token_size = 0

    # Returns the enclosed IO.
    getter io : IO

    # Creates a PullParser which will consume the contents of *io*.
    def initialize(@io : IO); end

    # Sets the cursor to the character at *index* in the current line.
    # Raises `ParseException` with the given message if *index* is out
    # of bounds.
    def at(index : Int,
           message : String = "Cursor out of current line") : self
      at index, 1, message
    end

    # Sets the cursor at *start* spanning *count* or less (if there
    # aren't enough) characters in the current line. Raises
    # `ParseException` with the given message if *start* is out of
    # bounds.
    def at(start : Int,
           count : Int,
           message : String = "Cursor out of current line") : self
      set_cursor(start, count) { error(message) }
      self
    end

    # Sets the cursor at *range* in the current line. Raises
    # `ParseException` with the given message if *range* is out of
    # bounds.
    def at(range : Range,
           message : String = "Cursor out of current line") : self
      bytesize = @line.try(&.bytesize) || 0
      if index_and_count = Indexable.range_to_index_and_count(range, bytesize)
        at(*index_and_count, message)
      else
        raise error(message)
      end
    end

    # Sets the cursor to the character at *index* in the current line.
    # If *index* is out of bounds, the current token will be set to
    # `nil`.
    def at?(index : Int) : self
      at? index, 1
    end

    # Sets the cursor at *start* spanning *count* or less (if there
    # aren't enough) characters in the current line. If *start* is out
    # of bounds, the current token will be set to `nil`.
    def at?(start : Int, count : Int) : self
      set_cursor(start, count) { return self }
      self
    end

    # Sets the cursor at *range* in the current line. If *range* is out
    # of bounds, the current token will be set to `nil`.
    def at?(range : Range) : self
      bytesize = @line.try(&.bytesize) || 0
      if index_and_count = Indexable.range_to_index_and_count(range, bytesize)
        at?(*index_and_count)
      end
      self
    end

    # Returns the first character of the curren token. Raises
    # `ParseException` with the message if the token is not set.
    def char(message : String = "Empty token") : Char
      char? || error(message)
    end

    # Returns the first character of the curren token, or `nil` if it is
    # not set.
    def char? : Char?
      if token = current_token
        token[0].unsafe_chr
      end
    end

    # Sets the current token to the next *count* characters in the
    # current line. If there are no more characters, the token will be
    # empty.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.next_line
    # pull.consume(4).str?  # => "123 "
    # pull.consume(2).str?  # => "45"
    # pull.consume(20).str? # => "6"
    # pull.consume(10).str? # => nil
    # ```
    def consume(count : Int) : self
      unless @buffer.empty?
        @buffer += @token_size
        @token_size = Math.min @buffer.size, count
      end
      self
    end

    # Sets the current token to the next characters in the current line
    # for which the given block is truthy. If the block is always
    # falsey, the token will be empty.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("abc def\n1234 56 789\n")
    # pull.next_line
    # pull.consume(&.alphanumeric?).str? # => "123"
    # pull.consume(&.alphanumeric?).str? # => nil
    # pull.consume(&.whitespace?).str?   # => " "
    # pull.consume(&.alphanumeric?).str? # => "456"
    # pull.consume(&.alphanumeric?).str? # => nil
    # ```
    def consume(& : Char -> Bool) : self
      unless @buffer.empty?
        @buffer += @token_size
        @token_size = 0
        ptr = @buffer.to_unsafe
        while ptr.value != 0 && yield ptr.value.unsafe_chr
          ptr += 1
        end
        @token_size = (ptr - @buffer.to_unsafe).to_i
      end
      self
    end

    # Reads the next characters in the current line until the first
    # occurrence of *char* or end of line is reached. Returns `nil` at
    # end of line.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.next_line
    # pull.consume_until(' ').str? # => "123"
    # pull.consume_until('4').str? # => " "
    # pull.consume_until('x').str? # => "456"
    # pull.consume_until('x').str? # => nil
    # ```
    def consume_until(char : Char) : self
      consume &.!=(char)
    end

    # Reads the next characters in the current line until the given
    # block is truthy or end of line is reached. Returns `nil` at end of
    # line.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.next_line
    # pull.consume_until(&.whitespace?).str?    # => "123"
    # pull.consume_until(&.in_set?("0-9")).str? # => " "
    # pull.consume_until(&.whitespace?).str?    # => "456"
    # pull.consume_until(&.alphanumeric?).str?  # => nil
    # ```
    def consume_until(& : Char -> Bool) : self
      consume { |char| (yield char).! }
    end

    # Returns the current line, or `nil` if it is not set.
    def current_line : String?
      @line
    end

    # Yields each line in the enclosed IO.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.each_line { |line| puts line }
    # ```
    #
    # Prints out:
    #
    # ```text
    # 123 456
    # 789
    # ```
    #
    # Note that the current line will be also yielded if it is set.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.next_line    # reads and sets the current line
    # pull.current_line # => "123 456"
    # pull.each_line { |line| puts line }
    # ```
    #
    # Prints out:
    #
    # ```text
    # 123 456
    # 789
    # ```
    def each_line(& : String ->) : Nil
      if line = @line
        yield line
      end
      while line = next_line
        yield line
      end
    end

    # Returns `true` at the end of file, otherwise `false`.
    #
    # NOTE: This method attempts to read a line from the enclosed IO if
    # the current line is not set, so calling `#next_line` after this
    # could inadvertently discard a line.
    def eof? : Bool
      @line.nil? && next_line.nil?
    end

    # Returns `true` if the current token is at the end of line,
    # otherwise `false`.
    #
    # If no current line is set (at the beginning or end of file), it
    # returns `true` as well.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.eol? # => true (no current line)
    # pull.next_line
    # pull.eol?            # => false (beginning of line)
    # pull.next_token.str? # => "123"
    # pull.eol?            # => false
    # pull.next_token.str? # => "456"
    # pull.eol?            # => false
    # pull.next_token.str? # => nil
    # pull.eol?            # => true
    # ```
    def eol? : Bool
      @buffer.empty?
    end

    # Raises `ParseException` with the given message. The exception will
    # hold the location of the current line and token if set.
    #
    # The current token is accessible via the named substitution
    # `%{token}`.
    def error(message : String) : NoReturn
      filepath = (io = @io).is_a?(File) ? io.path : nil
      loc = location

      loc_str = "#{loc[0]}:#{loc[1] + 1}"
      replacements = {
        token:         str?.try(&.inspect),
        file:          filepath,
        loc:           loc_str,
        loc_with_file: filepath ? "#{filepath}:#{loc_str}" : loc_str,
      }
      raise ParseException.new(message % replacements, filepath, @line || "", loc)
    end

    # Checks if the current token is one character long and equals
    # *expected*, else raises `ParseException`.
    #
    # If *message* is given, it is used as the parse error. Use
    # `"%{expected}"` and `"%{actual}"` as placeholders for the expected
    # and actual values.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("1 2 3 4 5 6\n789\n")
    # pull.next_line
    # pull.next_token
    # pull.expect('1').char? # => '1'
    # pull.expect 'a'        # raises ParseException (123 != 'a')
    # pull.next_line
    # pull.expect 'a' # raises ParseException (empty token)
    # ```
    def expect(
      expected : Char,
      message : String = "Expected %{expected}, got %{actual}"
    ) : self
      actual = char?
      return self if actual == expected && @token_size == 1

      actual = str? if @token_size > 1
      error message % {expected: expected.inspect, actual: actual.inspect}
    end

    # Checks if the current token is one character long and it is within
    # the given range of characters, else raises `ParseException`.
    #
    # If *message* is given, it is used as the parse error. Use
    # `"%{expected}"` and `"%{actual}"` as placeholders for the expected
    # and actual values.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("a b c d e f")
    # pull.next_line
    # pull.next_token.expect('a'..'c').char? # => 'a'
    # pull.next_token.expect('a'..'c').char? # => 'b'
    # pull.next_token.expect('a'..'c').char? # => 'c'
    # pull.next_token.expect 'a'..'c'        # raises ParseException ('d' not in 'a'..'c')
    # pull.next_line
    # pull.expect 'a'..'c' # raises ParseException (empty token)
    # ```
    def expect(
      expected : Range(Char?, Char?),
      message : String = "Expected %{actual} to be within %{expected}"
    ) : self
      actual = char?
      return self if actual && actual.in?(expected) && @token_size == 1

      actual = str? if @token_size > 1
      error message % {expected: expected, actual: actual.inspect}
    end

    # Checks if the current token is one character long and equals
    # to any *expected*, else raises `ParseException`.
    #
    # If *message* is given, it is used as the parse error. Use
    # `"%{expected}"` and `"%{actual}"` as placeholders for the expected
    # and actual values.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("1 a 2 b 3 c\n789\n")
    # pull.next_line
    # pull.next_token.expect({'1', '2', '3'}).char? # => '1'
    # pull.next_token.expect({'1', '2', '3'})       # raises ParseException ('a' != 1, 2, and 3)
    # pull.next_line
    # pull.expect({'1', '2', '3'}) # raises ParseException (empty token)
    # ```
    def expect(
      expected : Enumerable(Char),
      message : String = "Expected %{expected}, got %{actual}"
    ) : self
      actual = char?
      return self if actual.in?(expected) && @token_size == 1

      expected = expected.sentence(
        pair_separator: " or ", tail_separator: ", or ", &.inspect)
      actual = str? if @token_size > 1
      error message % {expected: expected, actual: actual.inspect}
    end

    # Checks if the current token equals *expected*, else raises
    # `ParseException`.
    #
    # If *message* is given, it is used as the parse error. Use
    # `"%{expected}"` and `"%{actual}"` as placeholders for the expected
    # and actual values.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.next_line
    # pull.next_token
    # pull.expect("123").str? # => "123"
    # pull.expect "abc"       # raises ParseException (123 != abc)
    # pull.next_line
    # pull.expect "456" # raises ParseException (empty token)
    # ```
    def expect(
      expected : String,
      message : String = "Expected %{expected}, got %{actual}"
    ) : self
      actual = str? || ""
      unless actual == expected
        error message % {expected: expected.inspect, actual: actual.inspect}
      end
      self
    end

    # Checks if the current token matches *pattern*, else raises
    # `ParseException`.
    #
    # If *message* is given, it is used as the parse error. Use
    # `"%{expected}"` and `"%{actual}"` as placeholders for the expected
    # and actual values.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.next_line
    # pull.next_token
    # pull.expect(/[0-9]+/).str? # => "123"
    # pull.expect /[a-z]+/       # raises ParseException (123 does not match [a-z]+)
    # pull.next_line
    # pull.expect /[0-9]+/ # raises ParseException (empty token)
    # ```
    #
    # NOTE: The entire token is returned even if the match is partial.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123abc\n789\n")
    # pull.next_line
    # pull.next_token
    # pull.expect(/[a-z]+/).str? # => "123abc"
    # pull.expect(/[0-9]+/).str? # => "123abc"
    # ```
    #
    # Use anchors to ensure full match.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123abc\n789\n")
    # pull.next_line
    # pull.next_token.expect /^[a-z]+$/ # raises ParseException
    # ```
    def expect(
      pattern : Regex,
      message : String = "Expected %{actual} to match %{expected}"
    ) : self
      actual = str? || ""
      unless actual.matches?(pattern)
        error message % {expected: pattern.inspect, actual: actual.inspect}
      end
      self
    end

    # Checks if the current token equals any of *expected*, else raises
    # `ParseException`.
    #
    # If *message* is given, it is used as the parse error. Use
    # `"%{expected}"` and `"%{actual}"` as placeholders for the expected
    # and actual values.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.next_line
    # pull.next_token
    # pull.expect(["123", "456"]).str? # => "123"
    # pull.next_token
    # pull.expect(["123", "456"]).str? # => "456"
    # pull.expect(["abc", "def"])      # raises ParseException ("456" != "abc" or "def")
    # pull.next_token
    # pull.expect(["123", "456"]) # raises ParseException (empty token)
    # ```
    def expect(
      expected : Enumerable(String),
      message : String = "Expected %{expected}, got %{actual}"
    ) : self
      actual = str? || ""
      unless actual.in?(expected)
        expected = expected.sentence(
          pair_separator: " or ", tail_separator: ", or ", &.inspect)
        error message % {expected: expected, actual: actual.inspect}
      end
      self
    end

    # Same as `expect` but advances to the next token first.
    def expect_next(
      expected : String,
      message : String = "Expected %{expected}, got %{actual}"
    ) : self
      next_token.expect expected, message
    end

    # :ditto:
    def expect_next(
      pattern : Regex,
      message : String = "Expected %{actual} to match %{expected}"
    ) : self
      next_token.expect pattern, message
    end

    # :ditto:
    def expect_next(
      expected : Enumerable(String),
      message : String = "Expected %{expected}, got %{actual}"
    ) : self
      next_token.expect expected, message
    end

    # Parses and returns the floating-point number represented by the
    # current token. Raises `ParseException` with the given message if
    # the token is not set or it is not a valid float representation.
    def float(message : String = "Invalid real number") : Float64
      float? || error(message)
    end

    # Parses and returns the floating-point number represented by the
    # current token. Returns the given default value if the token is
    # blank. Raises `ParseException` if the token is not set or it is
    # not a valid float representation.
    def float(if_blank default : Float64) : Float64
      if !(token = current_token) || token.all?(&.unsafe_chr.ascii_whitespace?)
        default
      else
        float
      end
    end

    # Parses and returns the floating-point number represented by the
    # current token, or `nil` if the token is not set or it is not a
    # valid float representation.
    def float? : Float64?
      internal_parse do |bytes|
        endptr = bytes.to_unsafe + bytes.size
        # set endptr's position to zero so strtod does not read beyond it
        old_value = endptr.value
        endptr.value = 0
        value = LibC.strtod bytes, out ptr
        endptr.value = old_value
        return if ptr == bytes.to_unsafe # blank string
        while ptr != endptr && ptr.value.unsafe_chr.ascii_whitespace?
          ptr += 1
        end

        value if ptr == endptr
      end
    end

    # Parses and returns the integer represented by the current token.
    # Raises `ParseException` with the given message if the token is not
    # set or it is not a valid number.
    def int(message : String = "Invalid integer") : Int32
      int? || error(message)
    end

    # Parses and returns the integer represented by the current token.
    # Returns the given default value if the token is blank. Raises
    # `ParseException` if the token is not set or it is not a valid
    # number.
    def int(if_blank default : Int32) : Int32
      if !(token = current_token) || token.all?(&.unsafe_chr.ascii_whitespace?)
        default
      else
        int
      end
    end

    # Parses and returns the integer represented by the current token,
    # or `nil` if the token is not set or it is not a valid number.
    def int? : Int32?
      internal_parse do |bytes|
        ptr = bytes.to_unsafe
        endptr = ptr + bytes.size

        while ptr != endptr && ptr.value.unsafe_chr.ascii_whitespace?
          ptr += 1
        end

        sign = 1
        case ptr.value.unsafe_chr
        when '-'
          sign = -1
          ptr += 1
        when '+'
          ptr += 1
        end

        digits = 0
        value = 0
        while ptr != endptr
          char = ptr.value.unsafe_chr
          break unless '0' <= char <= '9' # return on invalid character
          value *= 10
          old = value
          value &+= char - '0'
          return if value < old # return on overflow
          digits += 1
          ptr += 1
        end

        while ptr != endptr && ptr.value.unsafe_chr.ascii_whitespace?
          ptr += 1
        end

        value * sign if ptr == endptr && digits > 0
      end
    end

    # Returns the current line starting at the current token if set. An
    # empty string is returned at the end of line. Raises
    # `ParseException` with the given message at end of file.
    #
    # NOTE: This method does not change the cursor.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.next_line
    # # token is not set, returns entire line
    # pull.line # => "123 456"
    # pull.next_token
    # # token is "123", returns line starting at "123"
    # pull.line # => "123 456"
    # pull.next_token
    # # token is "456", returns line starting at "456"
    # pull.line # => "456"
    # ```
    def line(message : String = "End of file") : String
      if @line
        String.new(@buffer)
      else
        error(message)
      end
    end

    # Reads and returns the next line from the enclosed IO, or `nil` if
    # called at the end of the IO.
    def next_line : String?
      @line = @io.gets
      @buffer = @line.try(&.to_slice) || Bytes.empty
      @token_size = 0
      @line_number += 1
      @line
    end

    {% for type in [Float64, Int32, String] %}
      {% method = type == String ? "str" : type.stringify.downcase.gsub(/\d/, "") %}
      {% suffix = type.name.stringify.downcase.chars[0] %}

      # Reads the next token in the current line, and interprets it via
      # `#{{method.id}}`, which raises `ParseException` at the end of
      # line or if the token is an invalid representation.
      def next_{{suffix.id}} : {{type}}
        next_token
        {{method.id}}
      end

      # Reads the next token in the current line, and interprets it via
      # `#{{method.id}}`, which raises `ParseException` with the given
      # message at the end of line or if the token is an invalid
      # representation.
      def next_{{suffix.id}}(message : String) : {{type}}
        next_token
        {{method.id}} message
      end

      # Reads the next token in the current line, and interprets it via
      # `#{{method.id}}?`, which returns `nil` at the end of line or if
      # the token is an invalid representation.
      def next_{{suffix.id}}? : {{type}}?
        next_token
        {{method.id}}?
      end
    {% end %}

    # Sets the current token to the next consecutive non-whitespace
    # characters in the current line.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("abc def\n1234 56 789\n")
    # pull.next_token.str? # => nil
    # pull.next_line       # place the parser at the first line
    # pull.next_token.str? # => "abc"
    # pull.next_token.str? # => "def"
    # pull.next_token.str? # => nil
    # pull.next_line       # place the parser at the second line
    # pull.next_token.str? # => "1234"
    # pull.next_token.str? # => "56"
    # pull.next_token.str? # => "789"
    # pull.next_token.str? # => nil
    # pull.next_line       # place the parser at the end of IO
    # pull.next_token.str? # => nil
    # ```
    def next_token : self
      skip_whitespace.consume(&.ascii_whitespace?.!)
    end

    # Yields the current token and returns the parsed value. Raises
    # `ParseException` with the given message if no token is set or the
    # block returns `nil`.
    def parse(
      message : String = "Could not parse %{token} at %{loc_with_file}",
      & : String -> T?
    ) : T forall T
      parse? { |str| yield str } || error(message)
    end

    # Yields the current token if set and returns the parsed value.
    # Raises `ParseException` with the given message if the block
    # returns `nil`. If no token is set, returns *default*.
    def parse_if_present(
      message : String = "Could not parse %{token} at %{loc_with_file}",
      default : _ = nil,
      & : String -> _
    )
      parse? do |str|
        (yield str) || error(message)
      end || default
    end

    # Yields the current token if set and returns the parsed value.
    def parse?(& : String -> T?) : T? forall T
      internal_parse do |bytes|
        yield String.new(bytes)
      end
    end

    # Yields the next token if present and returns the parsed value.
    # Raises `ParseException` with the given message if no token is
    # found or the block returns `nil`.
    def parse_next(
      message : String = "Could not parse %{token} at %{loc_with_file}",
      & : String -> T?
    ) : T forall T
      parse_next? { |str| yield str } || error(message)
    end

    # Yields the next token if present and returns the parsed value.
    # Raises `ParseException` with the given message if the block
    # returns `nil`. If no token is found, returns *default*.
    def parse_next_if_present(
      message : String = "Could not parse %{token} at %{loc_with_file}",
      default : _ = nil,
      & : String -> _
    )
      parse_next? do |str|
        (yield str) || error(message)
      end || default
    end

    # Yields the next token if present and returns the parsed value.
    def parse_next?(& : String -> T?) : T? forall T
      next_token
      if bytes = current_token
        yield String.new(bytes)
      end
    end

    # Returns the character after the current token, or `nil` if empty.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.next_line
    # pull.peek            # => '1' (first character at the beginning of line)
    # pull.peek            # => '1' (`#peek` does not consume characters)
    # pull.next_token.str? # => "123"
    # pull.peek            # => ' ' (after the current token)
    # pull.next_token.str? # => "456"
    # pull.peek            # => nil (end of line)
    #
    def peek : Char?
      (@buffer + @token_size).first?.try(&.unsafe_chr)
    end

    # Returns the rest of the line (after the current token), or `nil`
    # if the cursor is at end of line. Raises `ParseException` with the
    # given message at end of file.
    #
    # NOTE: The cursor will span the entire returned string.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("123 456\n789\n")
    # pull.next_line
    # pull.next_s?      # => "123"
    # pull.rest_of_line # => " 456"
    # pull.str?         # => " 456"
    # pull.next_s?      # => nil
    # ```
    def rest_of_line(message : String = "End of file") : String?
      if @line
        @buffer += @token_size
        @token_size = @buffer.size
        String.new(@buffer) unless @buffer.empty?
      else
        error(message)
      end
    end

    # Sets the cursor at the beginning of the current line if set.
    def rewind_line : self
      set_cursor(0, 0) { }
      self
    end

    # Discards blank lines.
    def skip_blank_lines : self
      while next_line.presence.nil?; end
      self
    end

    # Skips whitespace characters.
    #
    # The cursor is placed at the first non-whitespace character, but it
    # is not consumed.
    #
    # ```
    # pull = PullParser.new IO::Memory.new("  123 456\n789\n")
    # pull.next_line
    # pull.skip_whitespace
    # pull.str? # => nil # token size is zero
    # pull.line # => "123 456"
    # ```
    def skip_whitespace
      consume &.ascii_whitespace?
      @buffer += @token_size
      @token_size = 0
      self
    end

    # Returns the current token as a string. Raises `ParseException`
    # with the given message if the token is not set.
    def str(message : String = "Empty token") : String
      str? || error(message)
    end

    # Returns the current token as a string, or `nil` if it is not set.
    def str? : String?
      internal_parse do |bytes|
        String.new(bytes)
      end
    end

    # Returns the bytes of the current token if it is set.
    private def current_token : Bytes?
      @buffer[0, @token_size] if @token_size > 0
    end

    # Returns a tuple of line number, column number and cursor size.
    private def location : Tuple(Int32, Int32, Int32)
      return {@line_number, 0, 0} unless line = @line
      column_number = @buffer.empty? ? line.bytesize : @buffer.to_unsafe - line.to_unsafe
      {@line_number, column_number.to_i, @token_size.to_i}
    end

    # Yields the current token if set and returns the parsed value.
    def internal_parse(& : Bytes -> T?) : T? forall T
      if token = current_token
        yield token
      end
    end

    # Sets the cursor to *size* or less characters starting at *offset*.
    # Yields if current line is not set or *offset* is out of bounds.
    private def set_cursor(offset : Int, size : Int, &)
      raise ArgumentError.new "Negative size: #{size}" if size < 0
      if line = @line
        if offset < line.bytesize
          @buffer = line.to_slice + offset
          @token_size = Math.min @buffer.size, size
        else
          @buffer = Bytes.empty
          @token_size = 0
          yield
        end
      else
        yield
      end
    end
  end
end
