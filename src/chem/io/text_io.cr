# Buffered `IO` intended to read and parse plain text only.
#
# Most methods return a `String` object, but there are parsing methods
# for integers (`#read_int`) and floats (`#read_float`) as well, which
# provide implementations faster than calling `String#to_i` or
# `String#to_f` would be. In general, intermediary memory allocations
# are avoided as much as possible.
#
# NOTE: Only ASCII enconding is supported.
class Chem::IO::TextIO
  @buffer = Bytes.empty

  # Closes the underlying `IO`.
  delegate close, to: @io

  # Creates a new `TextIO` that wraps *io* and sets an internal buffer
  # of size *buffer_size*.
  #
  # NOTE: *buffer_size* should be large enough to hold the entire string
  # representation of a expected value or line, otherwise some methods
  # may produce incorrect results.
  def initialize(@io : ::IO, buffer_size = 8192)
    @buffer_ = Bytes.new buffer_size
  end

  # Peeks and yields the current character to the given block and
  # returns the returned value. Returns `false` at end of file.
  #
  # ```
  # io = TextIO.new IO::Memory.new("abcdef")
  # io.check &.alphanumeric? # => true
  # io.check &.number?       # => false
  # io.read                  # => 'a'
  # ```
  def check(& : Char -> Bool) : Bool
    return false unless chr = peek
    yield chr
  end

  # Returns `true` if the current byte is equal to *byte*, else `false`.
  # Returns `false` at end of file.
  #
  # ```
  # io = TextIO.new IO::Memory.new("abcdef")
  # io.check 97  # => true
  # io.check 128 # => false
  # io.read_byte # => 97
  # ```
  def check(byte : Int) : Bool
    peek_byte == byte
  end

  # Returns `true` if the current character is equal to *char*, else
  # `false`. Returns `false` at end of file.
  #
  # ```
  # io = TextIO.new IO::Memory.new("abcdef")
  # io.check 'A' # => false
  # io.check 'a' # => true
  # io.read      # => 'a'
  # ```
  def check(char : Char) : Bool
    peek == char
  end

  # Returns `true` if the current character is included in the given
  # collection, else `false`. Returns `false` at end of file.
  #
  # ```
  # io = TextIO.new IO::Memory.new("abcdef")
  # io.check 'A', 'a', 'B', 'b'   # => true
  # io.check ['A', 'a', 'B', 'b'] # => true
  # io.check 'b', 'B'             # => false
  # io.read                       # => 'a'
  # ```
  def check(*charsets : Char | Enumerable(Char)) : Bool
    check charsets
  end

  # :ditto:
  def check(charsets : Enumerable(Char | Enumerable(Char))) : Bool
    if char = peek
      charsets.any? &.===(char)
    else
      false
    end
  end

  # Returns `true` if the next characters are equal to *str*, else
  # `false`. Returns `false` at end of file or if the number of
  # available bytes is less than the bytesize of *str*.
  #
  # ```
  # io = TextIO.new IO::Memory.new("abcdef")
  # io.check "abcd"    # => true
  # io.check "abcdef"  # => true
  # io.check "abcdefg" # => false
  # io.check "def"     # => false
  # io.read            # => 'a'
  # ```
  def check(str : String) : Bool
    peek_bytes(str.bytesize) == str.to_slice
  end

  # Returns `true` if the next characters are equal to any of the
  # strings included the given collection, else `false`. Returns `false`
  # at end of file.
  #
  # ```
  # io = TextIO.new IO::Memory.new("abcdef")
  # io.check "def", "abcd"       # => true
  # io.check %w(def abcd)        # => true
  # io.check "abcdef", "abcdefg" # => true
  # io.check "bcd", "def"        # => false
  # io.read                      # => 'a'
  # ```
  def check(*strings : String) : Bool
    check strings
  end

  # :ditto:
  def check(strings : Enumerable(String)) : Bool
    strings.any? { |str| check str }
  end

  # Returns the number of consecutive bytes in the `IO` for which the
  # given block returns `true`.
  #
  # The optional *offset* argument specifies the position to start to
  # count from.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello world")
  # io.count_bytes_while(&.chr.number?)    # => 3
  # io.read(4)                             # => "123 "
  # io.count_bytes_while(&.chr.lowercase?) # => 5
  # ```
  #
  # NOTE: this method does not advance the `IO`.
  def count_bytes_while(offset : Int = 0, & : UInt8 -> Bool) : Int32
    while offset < @buffer.size || fill_buffer(fully: false) > 0
      (@buffer + offset).each do |byte|
        break unless yield byte
        offset += 1
      end
      break if offset < @buffer.size
    end
    offset
  end

  # Consumes and yields consecutive bytes in the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("abcdef 123")
  # io.each_byte do |byte|
  #   break if byte.chr.whitespace?
  #   print byte.chr, ' '
  # done
  # ```
  #
  # Prints:
  #
  # ```
  # a b c d e f
  # ```
  #
  # Note that the yielded byte is not consumed when breaking out of the
  # loop, i.e., the space is the current character in the example.
  #
  # ```
  # io.read_to_end # => " 123"
  # ```
  def each_byte(& : UInt8 ->) : Nil
    until eof?
      until @buffer.empty?
        yield @buffer.to_unsafe.value
        @buffer += 1
      end
    end
  end

  # Returns `true` if there are no more bytes available in the `IO`,
  # else `false`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello")
  # io.eof? # => false
  # io.skip_to_end
  # io.eof? # => true
  # ```
  def eof? : Bool
    @buffer.empty? && fill_buffer == 0
  end

  # Returns `true` if there are no more characters in the current line,
  # else `false`. Returns `true` at end of file.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 \nhello\r\n\t world")
  # io.eol?                 # => false
  # io.read(3)              # => "123"
  # io.eol?                 # => true
  # io.read(1)              # => " "
  # io.eol?                 # => true
  # io.skip_whitespace.eol? # => false
  # io.read(5)              # => "hello"
  # io.eol?                 # => true
  # io.read(9)              # => "\r\n\t world"
  # io.eol?                 # => true
  # io.eof?                 # => true
  # ```
  #
  # Horizontal spaces in the current line are ignored unless
  # *ignore_spaces* is `false`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 \nhello")
  # io.eol?                       # => false
  # io.read(3)                    # => "123"
  # io.eol?                       # => true
  # io.eol?(ignore_spaces: false) # => false
  # io.read(1)                    # => " "
  # io.eol?                       # => true
  # io.eol?(ignore_spaces: false) # => true
  # ```
  def eol?(ignore_spaces : Bool = true) : Bool
    return true if eof?

    offset = 0
    if ignore_spaces
      until @buffer.empty? && fill_buffer(fully: false) == 0
        offset = @buffer.take_while(&.in?(32, 9)).size
        break if offset < @buffer.size
      end
    end
    bytes = @buffer + offset
    char = bytes.unsafe_fetch(0).unsafe_chr unless bytes.empty?
    char == '\r' || char == '\n'
  end

  # Peeks and returns the current character in the `IO`, if possible,
  # else `nil`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("hello")
  # io.peek    # => 'h'
  # io.peek    # => 'h'
  # io.read(5) # => "hello"
  # io.peek    # => nil
  # ```
  def peek : Char?
    peek_byte.try(&.unsafe_chr)
  end

  # Peeks and returns up to *count* characters in the `IO`, if possible.
  # Returns an empty string at end of file.
  #
  # ```
  # io = TextIO.new IO::Memory.new("hello world")
  # io.peek(4)  # => "hell"
  # io.peek(3)  # => "hel"
  # io.read(8)  # => "hello wo"
  # io.peek(10) # => "rld"
  # io.read(3)  # => "rld"
  # io.peek(5)  # => ""
  # io.eof?     # => true
  # ```
  def peek(count : Int) : String
    String.new peek_bytes(count)
  end

  # Peeks and returns the current byte in the `IO`, if possible,
  # else `nil`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("hello")
  # io.peek_byte # => 104
  # io.peek_byte # => 104
  # io.read(5)   # => "hello"
  # io.peek_byte # => nil
  # ```
  def peek_byte : UInt8?
    return nil if eof?
    @buffer.unsafe_fetch(0)
  end

  # Peeks and returns up to *count* bytes in the `IO`, if possible.
  # Returns an empty slice at end of file.
  #
  # ```
  # io = TextIO.new IO::Memory.new("hello world")
  # io.peek_bytes(4)  # => Bytes[104, 101, 108, 108]
  # io.peek_bytes(3)  # => Bytes[104, 101, 108]
  # io.read(8)        # => "hello wo"
  # io.peek_bytes(10) # => Bytes[114, 108, 100]
  # io.read(3)        # => "rld"
  # io.peek_bytes(5)  # => Bytes[]
  # io.eof?           # => true
  # ```
  def peek_bytes(count : Int) : Bytes
    fill_buffer(fully: false) if @buffer.size < count
    @buffer[0, Math.min(count, @buffer.size)]
  end

  # Peeks the current line in the `IO`, if possible. Returns an empty
  # string at end of file.
  #
  # ```
  # io = TextIO.new IO::Memory.new("The quick\n brown\t\tfox\njumps")
  # io.peek_line # => "The quick"
  # io.read_line # => "The quick"
  # io.peek_line # => " brown\t\tfox"
  # io.read_line # => " brown\t\tfox"
  # io.peek_line # => "jumps"
  # io.read_line # => "jumps"
  # io.peek_line # => ""
  # io.eof?      # => true
  # ```
  def peek_line : String
    return "" if eof?

    i = @buffer.unsafe_index('\n'.ord)
    fill_buffer(fully: false) unless i
    i = @buffer.unsafe_index('\n'.ord) || @buffer.size
    i -= 1 if i > 0 && @buffer.unsafe_fetch(i - 1) === '\r'
    String.new @buffer[0, i]
  end

  # Reads the next character in the `IO`. Raises `IO::EOFError` if there
  # are no more characters in the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("hello")
  # io.read # => 'h'
  # io.read # => 'e'
  # io.read # => 'l'
  # io.read # => 'l'
  # io.read # => 'o'
  # io.read # raises IO::EOFError
  # ```
  def read : Char
    read? || raise ::IO::EOFError.new
  end

  # Reads the next character in the `IO`. Returns `nil` if there are no
  # more characters in the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("hello")
  # io.read? # => 'h'
  # io.read? # => 'e'
  # io.read? # => 'l'
  # io.read? # => 'l'
  # io.read? # => 'o'
  # io.read? # => nil
  # ```
  def read? : Char?
    read_byte?.try(&.unsafe_chr)
  end

  # Reads up to *count* characters in the `IO`. Returns an empty string
  # at end of file.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello")
  # io.read(5) # => "123 h"
  # io.read(3) # => "ell"
  # io.read(5) # => "o"
  # io.read(4) # => ""
  # ```
  def read(count : Int) : String
    String.new read_bytes(count)
  end

  # Reads the next byte in the `IO`. Raises `IO::EOFError` if there
  # are no more bytes in the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("hello")
  # io.read_byte # => 104
  # io.read_byte # => 101
  # io.read_byte # => 108
  # io.read_byte # => 108
  # io.read_byte # => 111
  # io.read_byte # raises IO::EOFError
  # ```
  def read_byte : UInt8
    read_byte? || raise ::IO::EOFError.new
  end

  # Reads the next byte in the `IO`. Returns `nil` if there are no
  # more bytes in the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("hello")
  # io.read_byte? # => 104
  # io.read_byte? # => 101
  # io.read_byte? # => 108
  # io.read_byte? # => 108
  # io.read_byte? # => 111
  # io.read_byte? # => nil
  # ```
  def read_byte? : UInt8?
    fill_buffer unless @buffer.size > 0
    if byte = @buffer[0]?
      @buffer += 1
      byte
    end
  end

  # Reads up to *count* bytes in the `IO`. Returns an empty slice at end
  # of file.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello")
  # io.read_bytes(2)  # => Bytes[49, 50]
  # io.read_bytes(5)  # => Bytes[51, 32, 104, 101, 108]
  # io.read_bytes(10) # => Bytes[108, 111]
  # io.read_bytes(10) # => Bytes[]
  # io.eof?           # => true
  # ```
  def read_bytes(count : Int) : Bytes
    bytes = Bytes.new count
    until eof? || count <= 0
      read_bytes = Math.min(@buffer.size, count)
      @buffer[0, read_bytes].copy_to bytes + (bytes.size - count)
      @buffer += read_bytes
      count -= read_bytes
    end
    bytes[0, bytes.size - count]
  end

  # Reads the rest of bytes in the `IO`. Returns an empty slice if there
  # are no more bytes in the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello")
  # io.read(5)           # => "123 h"
  # io.read_bytes_to_end # => Bytes[101, 108, 108, 111]
  # io.read_bytes_to_end # => Bytes[]
  # io.eof?              # => true
  # ```
  def read_bytes_to_end : Bytes
    bytes = Bytes.empty
    until eof?
      bytes = bytes.concat @buffer
      @buffer = Bytes.empty
    end
    bytes
  end

  # Returns consecutive bytes in the `IO` until *delim* is found or the
  # end of the `IO` is reached.  Returns an empty slice if there are no
  # more bytes in the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello")
  # io.read_bytes_until(' ') # => Bytes[49, 50, 51]
  # io.read_bytes_until(108) # => Bytes[32, 104, 101]
  # io.read_bytes_until('Z') # => Bytes[108, 108, 111]
  # io.read_bytes_until('A') # => Bytes[]
  # io.eof?                  # => true
  # ```
  def read_bytes_until(delim : Char) : Bytes
    read_bytes_until delim.ord.to_u8
  end

  # :ditto:
  def read_bytes_until(delim : Int) : Bytes
    bytes = Bytes.empty
    loop do
      if i = @buffer.unsafe_index(delim)
        bytes = bytes.concat @buffer, i
        @buffer += i
        break
      else
        bytes = bytes.concat @buffer
        break if fill_buffer == 0
      end
    end
    bytes
  end

  # Returns the result of interpreting the next characters in the `IO`
  # as a decimal floating-point number. Raises `ParseException` if a
  # number couldn't be read.
  #
  # This method discards any leading whitespace first. Then, it reads as
  # many characters as possible that form a valid floating point
  # expression, which are then converted into a floating-point value.
  # Extraneous non-whitespace characters past the end of the number are
  # disallowed unless *strict* is `false`.
  #
  # ```
  # io = TextIO.new IO::Memory.new(" -123.45 1.23abc")
  # io.read_float                # => -123.45
  # io.read                      # => ' '
  # io.read_float                # raises ParseException
  # io.read_float(strict: false) # => 1.23
  # io.read_float                # raises ParseException
  # io.read(4)                   # => "abc"
  # ```
  #
  # NOTE: This method does not advance the `IO` when a number couldn't
  # be read.
  def read_float(strict : Bool = true) : Float64
    read_float?(strict) || parse_exception("Couldn't read a float")
  end

  # Returns the result of interpreting the next characters in the `IO`
  # as a decimal floating-point number. Returns `nil` if a number
  # couldn't be read.
  #
  # This method discards any leading whitespace first. Then, it reads as
  # many characters as possible that form a valid floating point
  # expression, which are then converted into a floating-point value.
  # Extraneous non-whitespace characters past the end of the number are
  # disallowed unless *strict* is `false`.
  #
  # ```
  # io = TextIO.new IO::Memory.new(" -123.45 1.23abc")
  # io.read_float?                # => -123.45
  # io.read                       # => ' '
  # io.read_float?                # => nil
  # io.read_float?(strict: false) # => 1.23
  # io.read_float?                # => nil
  # io.read(4)                    # => "abc"
  # ```
  #
  # NOTE: This method does not advance the `IO` when a number couldn't
  # be read.
  def read_float?(strict : Bool = true) : Float64?
    return if eof?

    value = LibC.strtod @buffer, out endptr
    n = (endptr - @buffer.to_unsafe).to_i

    # read more bytes when number may be cut (digits are at the end or
    # ending with 'E', 'e', '+', ',', '-', and '.')
    if n == @buffer.size ||
       (n == @buffer.size - 1 && @buffer[n]?.try(&.in?(69, 101, 43, 44, 45, 46))) ||
       (n == 0 && @buffer[0]?.try(&.ascii_whitespace?))
      fill_buffer fully: false
      value = LibC.strtod @buffer, pointerof(endptr)
      n = (endptr - @buffer.to_unsafe).to_i
    end

    if n > 0 && (!strict || endptr.value.unsafe_chr.ascii_whitespace?)
      @buffer += n
      return value
    end
  end

  # Returns the result of interpreting the next characters in the `IO`
  # as an integer. Raises `ParseException` if a number couldn't be read.
  #
  # This method discards any leading whitespace first. Then, it reads as
  # many characters as possible that can be converted into a valid
  # integer value. Extraneous non-whitespace characters past the end of
  # the number are disallowed unless *strict* is `false`.
  #
  # ```
  # io = TextIO.new IO::Memory.new(" -123 1.23abc")
  # io.read_int                # => -123
  # io.read                    # => ' '
  # io.read_int                # raises ParseException
  # io.read_int(strict: false) # => 1
  # io.read_int                # raises ParseException
  # io.read(3)                 # => ".23"
  # io.read_int                # raises ParseException
  # io.read(3)                 # => "abc"
  # ```
  #
  # NOTE: This method does not advance the `IO` when a number couldn't
  # be read.
  def read_int(strict : Bool = true) : Int32
    read_int?(strict) || parse_exception("Couldn't read an integer")
  end

  # Returns the result of interpreting the next characters in the `IO`
  # as an integer. Returns `nil` if a number couldn't be read.
  #
  # This method discards any leading whitespace first. Then, it reads as
  # many characters as possible that can be converted into a valid
  # integer value. Extraneous non-whitespace characters past the end of
  # the number are disallowed unless *strict* is `false`.
  #
  # ```
  # io = TextIO.new IO::Memory.new(" -123 1.23abc")
  # io.read_int?                # => -123
  # io.read                     # => ' '
  # io.read_int?                # => nil
  # io.read_int?(strict: false) # => 1
  # io.read_int?                # => nil
  # io.read(3)                  # => ".23"
  # io.read_int?                # => nil
  # io.read(3)                  # => "abc"
  # ```
  #
  # NOTE: This method does not advance the `IO` when a number couldn't
  # be read.
  def read_int?(strict : Bool = true) : Int32?
    offset = count_bytes_while &.ascii_whitespace?
    return nil if offset == @buffer.size

    sign = 1
    if (byte = @buffer.unsafe_fetch(offset)).ascii_sign?
      sign = -1 if byte == 45
      offset += 1
    end

    digits = 0
    value = 0
    while (offset + digits) < @buffer.size || fill_buffer(fully: false) > 0
      (@buffer + offset + digits).each do |byte|
        break unless byte.ascii_number?
        value *= 10
        old = value
        value &+= byte - 48
        return nil if value < old
        digits += 1
      end
      break if (offset + digits) < @buffer.size
    end

    if digits > 0
      if strict && (byte = @buffer[offset + digits]?)
        return unless byte.ascii_whitespace?
      end

      @buffer += offset + digits
      value * sign
    end
  end

  # Reads the current line in the `IO`. Raises `IO::EOFError` at end of
  # file.
  #
  # The the last carriage return (`\n` or `\r\n`) is removed from the
  # returned string.
  #
  # ```
  # io = TextIO.new IO::Memory.new("Lorem ipsum\ndolor sit amet\r\nabc")
  # io.read_line # => "Lorem ipsum"
  # io.read_line # => "dolor sit amet"
  # io.read_line # => "abc"
  # io.read_line # raises IO::EOFError
  # ```
  def read_line : String
    raise ::IO::EOFError.new if eof?
    bytes = read_bytes_until '\n'
    bytes = bytes[0, bytes.size - 1] if bytes[-1]? === '\r'
    @buffer += 1 unless @buffer.empty?
    String.new bytes
  end

  # Reads the rest of the characters in the `IO`. Returns an empty
  # string if there are no more characters in the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello")
  # io.read(2)     # => "12"
  # io.read_to_end # => "3 hello"
  # io.read_to_end # => ""
  # io.eof?        # => true
  # ```
  def read_to_end : String
    String.new read_bytes_to_end
  end

  # Returns consecutive characters in the `IO` until *delim* is found or
  # the end of the `IO` is reached.  Returns an empty string if there
  # are no more characters in the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello")
  # io.read_until(' ') # => "123"
  # io.read_until('o') # => " hell"
  # io.read_until('Z') # => "o"
  # io.eof?            # => true
  # io.read_until('A') # => ""
  # ```
  def read_until(delim : Char) : String
    String.new read_bytes_until(delim)
  end

  # Returns the result of interpreting the next characters in the `IO`
  # as a vector. Raises `ParseException` if a vector couldn't be read.
  #
  # A vector expression is defined as three consecutive decimal
  # floating-point numbers separated by whitespace. See `#read_float?`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("1.2 3.4 5.6 7.8 9.0")
  # io.read_vector? # => Chem::Spatial::Vector[1.2, 3.4, 5.6]
  # io.read_vector? # raises ParseException
  # ```
  #
  # NOTE: This method advances the `IO` even though a vector could be
  # read fully, i.e., the `IO` advances for each valid float.
  def read_vector : Chem::Spatial::Vector
    read_vector? || parse_exception("Couldn't read a vector")
  end

  # Returns the result of interpreting the next characters in the `IO`
  # as a vector. Returns `nil` if a vector couldn't be read.
  #
  # A vector expression is defined as three consecutive decimal
  # floating-point numbers separated by whitespace. See `#read_float?`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("1.2 3.4 5.6 7.8 9.0")
  # io.read_vector? # => Chem::Spatial::Vector[1.2, 3.4, 5.6]
  # io.read_vector? # => nil
  # ```
  #
  # NOTE: This method advances the `IO` even though a vector could be
  # read fully, i.e., the `IO` advances for each valid float.
  def read_vector? : Chem::Spatial::Vector?
    if (x = read_float?) && (y = read_float?) && (z = read_float?)
      Chem::Spatial::Vector.new x, y, z
    end
  end

  # Read consecutive word characters in the `IO`. Raises
  # `ParseException` if a word couldn't be read.
  #
  # Word characters are the same defined in regular expressions:
  # uppercase and lowercase letters, numbers, and underscore, but also
  # including hyphen.
  #
  # NOTE: Any leading whitespace is discarded.
  #
  # ```
  # str = "The 123 quick\n brown!\t\tfox-jumps"
  # io = TextIO.new IO::Memory.new(str)
  # io.read_word # => "The"
  # io.read_word # => "123"
  # io.read_word # => "quick"
  # io.read_word # => "brown"
  # io.read_word # raises ParseException
  # io.read      # => '!'
  # io.read_word # => "fox-jumps"
  # io.read_word # raises ParseException
  # io.eof?      # => true
  # ```
  def read_word : String
    read_word? || parse_exception("Couldn't read a word")
  end

  # Read consecutive word characters in the `IO`. Returns `nil` if a
  # word couldn't be read.
  #
  # Word characters are the same defined in regular expressions:
  # uppercase and lowercase letters, numbers, and underscore, but also
  # including hyphen.
  #
  # NOTE: Any leading whitespace is discarded.
  #
  # ```
  # str = "The 123 quick\n brown!\t\tfox-jumps"
  # io = TextIO.new IO::Memory.new(str)
  # io.read_word? # => "The"
  # io.read_word? # => "123"
  # io.read_word? # => "quick"
  # io.read_word? # => "brown"
  # io.read_word? # => nil
  # io.read       # => '!'
  # io.read_word? # => "fox-jumps"
  # io.read_word? # => nil
  # io.eof?       # => true
  # ```
  def read_word? : String?
    skip_whitespace
    word = scan &.ord.ascii_word?
    word unless word.empty?
  end

  # Reads consecutive characters in the `IO` for which the given block
  # returns `true`. Returns an empty string if the block returns `false`
  # immediately or there are no more characters in the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 abcdef \r\n56.7")
  # io.scan(&.number?)     # => "123"
  # io.scan(&.letter?)     # => ""
  # io.scan(&.whitespace?) # => " "
  # io.scan(&.letter?)     # => "abcdef"
  # io.scan { true }       # => " \r\n56.7"
  # io.scan { true }       # => ""
  # io.eof?                # => true
  # ```
  def scan(& : Char -> Bool) : String
    bytes = scan_bytes { |byte| yield byte.unsafe_chr }
    String.new bytes
  end

  # Reads consecutive characters in the `IO` that are included in the
  # given collection. Returns an empty string if the current character
  # is not included in the collection or there are no more characters in
  # the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 abcdef \r\n56.7")
  # io.scan 'a'..'z', '1'..'9', '\r', '\n'   # => "123"
  # io.scan 'a'..'z'                         # => ""
  # io.scan [' ', '\t', '\r', '\n']          # => " "
  # io.scan 'a'..'z'                         # => "abcdef"
  # io.scan ['0'..'9', '.', ' ', '\r', '\n'] # => " \r\n56.7"
  # io.scan 'a'..'z'                         # => ""
  # io.eof?                                  # => true
  # ```
  def scan(*sets : Char | Enumerable(Char)) : String
    scan sets
  end

  # :ditto:
  def scan(sets : Enumerable(Char | Enumerable(Char))) : String
    scan do |chr|
      sets.any? &.===(chr)
    end
  end

  # Reads consecutive bytes in the `IO` for which the given block
  # returns `true`. Returns an empty slice if the block returns `false`
  # immediately or there are no more bytes in the `IO`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 \t\nabc|def")
  # io.scan_bytes(&.chr.number?)     # => Bytes[49, 50, 51]
  # io.scan_bytes(&.chr.letter?)     # => Bytes[]
  # io.scan_bytes(&.chr.whitespace?) # => Bytes[32, 9, 13, 10]
  # io.scan_bytes(&.chr.letter?)     # => Bytes[97, 98, 99]
  # io.scan_bytes { true }           # => Bytes[124, 100, 101, 102]
  # io.scan_bytes { true }           # => ""
  # io.eof?                          # => true
  # ```
  def scan_bytes(& : UInt8 -> Bool) : Bytes
    bytes = Bytes.empty
    until eof?
      view = @buffer.take_while { |byte| yield byte }
      if view.empty?
        break
      elsif view.size < @buffer.size
        bytes = bytes.concat view
        @buffer += view.size
        break
      else
        bytes = bytes.concat @buffer
        @buffer = Bytes.empty
      end
    end
    bytes
  end

  # Reads and discards consecutive characters in the `IO` that are
  # included in the given collection. Returns `self`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("abc:_:def\n")
  # io.skip('a'..'z').peek        # => ':'
  # io.skip(':', '_').peek        # => 'd'
  # io.skip(['d', 'e', 'z']).peek # => 'f'
  # io.skip('0'..'9').peek        # => 'f'
  # io.skip('a'..'z', '\n').eof?  # => true
  # ```
  def skip(*sets : Char | Enumerable(Char)) : self
    skip sets
  end

  # :ditto:
  def skip(sets : Enumerable(Char | Enumerable(Char))) : self
    skip_while do |byte|
      sets.any? &.===(byte.unsafe_chr)
    end
    self
  end

  # Reads and discards up to *count* bytes in the `IO`. Returns `self`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello")
  # io.skip_bytes(4).read  # => 'h'
  # io.skip_bytes(3).read  # => 'o'
  # io.skip_bytes(10).eof? # => true
  # ```
  def skip_bytes(count : Int) : self
    while count > @buffer.size
      count -= @buffer.size
      break if fill_buffer == 0
    end
    @buffer = count < @buffer.size ? @buffer + count : Bytes.empty
    self
  end

  # Reads and discards the current line in the `IO`. Returns `self`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello\nabcdef \r\n567")
  # io.skip_line.read # => 'a'
  # io.skip_line.read # => '5'
  # io.skip_line.eof? # => true
  # ```
  def skip_line : self
    skip_until '\n'
    @buffer += 1 unless @buffer.empty?
    self
  end

  # Reads and discards horizontal space characters in the `IO`. Returns
  # `self`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("abc \t\ndef\thello\r\n123")
  # io.read(3)             # => "abc"
  # io.skip_spaces.read(4) # => "\ndef"
  # io.skip_spaces.read(5) # => "hello"
  # io.skip_spaces.read(5) # => "\r\n123"
  # io.skip_spaces.eof?    # => true
  # ```
  def skip_spaces : self
    skip ' ', '\t'
  end

  # Reads and discards bytes from the `IO` until there are no more
  # bytes. Returns `self`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello")
  # io.skip_to_end
  # io.eof? # => true
  # ```
  def skip_to_end : self
    @io.skip_to_end
    @buffer = Bytes.empty
    self
  end

  # Yields and discards consecutive bytes in the `IO` until the given
  # block returns `true`. Returns `self`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("  \t  \nhello")
  # io.skip_until(&.chr.letter?)
  # io.read_to_end # => "hello"
  # ```
  #
  # NOTE: The character for which the given block returns `true` is not
  # consumed and it becomes the current character.
  def skip_until(& : UInt8 -> Bool) : self
    skip_while { |byte| !(yield byte) }
  end

  # Yields and discards consecutive bytes in the `IO` that are not
  # included in the given collection. Returns `self`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("123 hello")
  # io.skip_until 'h', 'H'
  # io.read # => 'h'
  # ```
  def skip_until(*sets : Char) : self
    skip_until *sets.map(&.ord)
  end

  # :ditto:
  def skip_until(*sets : Int) : self
    until eof?
      if i = @buffer.unsafe_index(*sets)
        @buffer += i
        break
      end
      @buffer = Bytes.empty
    end
    self
  end

  # Yields and discards consecutive bytes in the `IO` for which the
  # given block return `true`. Returns `self`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("  \t  \nhello")
  # io.skip_while &.chr.whitespace?
  # io.peek # => 'h'
  # io.skip_while &.chr.number?
  # io.peek # => 'h'
  # io.skip_while &.chr.letter?
  # io.eof? # => true
  # ```
  def skip_while(& : UInt8 -> Bool) : self
    until eof?
      @buffer = @buffer.skip { |byte| yield byte }
      break unless @buffer.empty?
    end
    self
  end

  # Yields and discards consecutive whitespace characters in the `IO`.
  # Returns `self`.
  #
  # ```
  # io = TextIO.new IO::Memory.new("  \t  \nhello")
  # io.skip_whitespace.read # => 'h'
  # ```
  def skip_whitespace : self
    skip_while &.ascii_whitespace?
  end

  # Yields and discards consecutive word characters in the `IO`. Returns
  # `self`.
  #
  # Word characters are the same defined in regular expressions:
  # uppercase and lowercase letters, numbers, and underscore, but also
  # including hyphen.
  #
  # NOTE: Any leading whitespace is also discarded.
  #
  # ```
  # str = "The quick\n brown\t\tfox jumps \t\r\nover the lazy # dog\n"
  # io = TextIO.new IO::Memory.new str
  # io.skip_word
  # io.peek(2) # => " q"
  # io.skip_word
  # io.peek(3) # => "\n b"
  # ```
  def skip_word : self
    skip_whitespace
    skip_while &.ascii_word?
    self
  end

  # Reads bytes from the underlying `IO`. Returns the number of bytes
  # read.
  #
  # The internal buffer is fully filled, overwriting existing data.
  # However, if *fully* is `false`, the bytes in the buffer's view
  # (`@buffer`) are moved at the beginning of the buffer, and the
  # remaining bytes are filled only.
  private def fill_buffer(fully : Bool = true) : Int32
    if fully
      read_bytes = size = @io.read(@buffer_)
    else
      @buffer.copy_to @buffer_
      read_bytes = @io.read(@buffer_ + @buffer.size)
      size = read_bytes + @buffer.size
    end
    @buffer = @buffer_[0, size]
    read_bytes
  end

  # Raises a `ParseException` exception with *message*.
  private def parse_exception(message : String) : NoReturn
    raise ParseException.new(message)
  end
end
