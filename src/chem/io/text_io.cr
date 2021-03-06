class Chem::IO::TextIO
  @buffer = Bytes.empty

  delegate close, to: @io

  def initialize(@io : ::IO, buffer_size = 8192)
    @buffer_ = Bytes.new buffer_size
  end

  def check(& : Char -> Bool) : Bool
    return false unless chr = peek
    yield chr
  end

  def check(byte : Int) : Bool
    peek_byte == byte
  end

  def check(byte : Char) : Bool
    peek == byte
  end

  def check(*charsets : Char | Enumerable(Char)) : Bool
    check charsets
  end

  def check(charsets : Enumerable) : Bool
    if char = peek
      charsets.any? &.===(char)
    else
      false
    end
  end

  def check(str : String) : Bool
    peek_bytes(str.bytesize) == str.to_slice
  end

  def check(*strings : String) : Bool
    check strings
  end

  def check(strings : Enumerable(String)) : Bool
    strings.any? { |str| check str }
  end

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

  def each_byte(& : UInt8 ->) : Nil
    until eof?
      until @buffer.empty?
        yield @buffer.to_unsafe.value
        @buffer += 1
      end
    end
  end

  def eof? : Bool
    @buffer.empty? && fill_buffer == 0
  end

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

  def peek : Char?
    peek_byte.try(&.unsafe_chr)
  end

  def peek(count : Int) : String
    String.new peek_bytes(count)
  end

  def peek_byte : UInt8?
    return nil if eof?
    @buffer.unsafe_fetch(0)
  end

  def peek_bytes(count : Int) : Bytes
    fill_buffer(fully: false) if @buffer.size < count
    @buffer[0, Math.min(count, @buffer.size)]
  end

  def peek_line : String
    return "" if eof?

    i = @buffer.unsafe_index('\n'.ord)
    fill_buffer(fully: false) unless i
    i = @buffer.unsafe_index('\n'.ord) || @buffer.size
    i -= 1 if i > 0 && @buffer.unsafe_fetch(i - 1) === '\r'
    String.new @buffer[0, i]
  end

  def read : Char
    read? || raise ::IO::EOFError.new
  end

  def read? : Char?
    read_byte?.try(&.unsafe_chr)
  end

  def read(count : Int) : String
    String.new read_bytes(count)
  end

  def read_byte : UInt8
    read_byte? || raise ::IO::EOFError.new
  end

  def read_byte? : UInt8?
    fill_buffer unless @buffer.size > 0
    if byte = @buffer[0]?
      @buffer += 1
      byte
    end
  end

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

  def read_bytes_to_end : Bytes
    bytes = Bytes.empty
    until eof?
      bytes = bytes.concat @buffer
      @buffer = Bytes.empty
    end
    bytes
  end

  def read_bytes_until(delim : Char) : Bytes
    read_bytes_until delim.ord.to_u8
  end

  def read_bytes_until(byte : UInt8) : Bytes
    bytes = Bytes.empty
    loop do
      if i = @buffer.unsafe_index(byte)
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

  def read_float(strict : Bool = true) : Float64
    read_float?(strict) || parse_exception("Couldn't read a float")
  end

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

  def read_int(strict : Bool = true) : Int32
    read_int?(strict) || parse_exception("Couldn't read a integer")
  end

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

  def read_line : String
    raise ::IO::EOFError.new if eof?
    bytes = read_bytes_until '\n'
    bytes = bytes[0, bytes.size - 1] if bytes[-1]? === '\r'
    @buffer += 1 unless @buffer.empty?
    String.new bytes
  end

  def read_to_end : String
    String.new read_bytes_to_end
  end

  def read_until(delim : Char) : String
    String.new read_bytes_until(delim)
  end

  def read_vector : Chem::Spatial::Vector
    read_vector? || parse_exception("Couldn't read a vector")
  end

  def read_vector? : Chem::Spatial::Vector?
    if (x = read_float?) && (y = read_float?) && (z = read_float?)
      Chem::Spatial::Vector.new x, y, z
    end
  end

  def read_word : String
    read_word? || raise ::IO::EOFError.new
  end

  def read_word? : String?
    skip_whitespace
    word = scan &.ord.ascii_word?
    word unless word.empty?
  end

  def scan(& : Char -> Bool) : String
    bytes = scan_bytes { |byte| yield byte.unsafe_chr }
    String.new bytes
  end

  def scan(*sets : Char | Enumerable(Char)) : String
    scan sets
  end

  def scan(sets : Enumerable) : String
    scan do |chr|
      sets.any? &.===(chr)
    end
  end

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

  def skip(*sets : Char | Enumerable(Char)) : self
    skip sets
  end

  def skip(sets : Enumerable) : self
    skip_while do |byte|
      sets.any? &.===(byte.unsafe_chr)
    end
    self
  end

  def skip_bytes(count : Int) : self
    while count > @buffer.size
      count -= @buffer.size
      break if fill_buffer == 0
    end
    @buffer = count < @buffer.size ? @buffer + count : Bytes.empty
    self
  end

  def skip_line : self
    skip_until '\n'
    @buffer += 1 unless @buffer.empty?
    self
  end

  def skip_spaces : self
    skip ' ', '\t'
  end

  def skip_to_end : self
    @io.skip_to_end
    @buffer = Bytes.empty
    self
  end

  def skip_until(& : UInt8 -> Bool) : self
    skip_while { |byte| !(yield byte) }
  end

  def skip_until(*delim : Char) : self
    skip_until *delim.map(&.ord)
  end

  def skip_until(*bytes : Int) : self
    until eof?
      if i = @buffer.unsafe_index(*bytes)
        @buffer += i
        break
      end
      @buffer = Bytes.empty
    end
    self
  end

  def skip_while(& : UInt8 -> Bool) : self
    until eof?
      @buffer = @buffer.skip { |byte| yield byte }
      break unless @buffer.empty?
    end
    self
  end

  def skip_whitespace : self
    skip_while &.ascii_whitespace?
  end

  def skip_word : self
    skip_whitespace
    skip_until &.ascii_whitespace?
    self
  end

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

  private def parse_exception(message : String) : NoReturn
    raise ParseException.new(message)
  end
end
