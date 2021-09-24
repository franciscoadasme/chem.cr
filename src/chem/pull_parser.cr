module Chem
  class PullParser
    @buffer : Bytes = Bytes.empty
    @line : String?
    @line_number = 0
    @token_size = 0

    def initialize(@io : IO); end

    def at(index : Int) : self
      at index, 1
    end

    def at(start : Int, count : Int) : self
      set_cursor(start, count) { error("Index out of bounds") }
      self
    end

    def at?(index : Int) : self
      at? index, 1
    end

    def at?(start : Int, count : Int) : self
      set_cursor(start, count) { return self }
      self
    end

    def char : Char
      char? || error("End of line")
    end

    def char? : Char?
      if token = current_token
        token[0].unsafe_chr
      end
    end

    def current_line : String?
      @line
    end

    def each_line(& : String ->) : Nil
      if line = @line
        yield line
      end
      while line = next_line
        yield line
      end
    end

    def eof? : Bool
      @line.nil? && next_line.nil?
    end

    def error(message : String) : NoReturn
      raise ParseException.new(
        message,
        (io = @io).is_a?(File) ? io.path : nil,
        @line || "",
        location
      )
    end

    def float : Float64
      float? || error("Invalid real number")
    end

    def float(default : Float64) : Float64
      if (token = current_token) && token.all?(&.unsafe_chr.ascii_whitespace?)
        default
      else
        float
      end
    end

    def float? : Float64?
      parse do |bytes|
        endptr = bytes.to_unsafe + bytes.size
        # set endptr's position to zero so strtod does not read beyond it
        old_value = endptr.value
        endptr.value = 0
        value = LibC.strtod bytes, out ptr
        endptr.value = old_value
        while ptr != endptr && ptr.value.unsafe_chr.ascii_whitespace?
          ptr += 1
        end

        value if ptr == endptr
      end
    end

    def int : Int32
      int? || error("Invalid integer")
    end

    def int(default : Int32) : Int32
      if (token = current_token) && token.all?(&.unsafe_chr.ascii_whitespace?)
        default
      else
        int
      end
    end

    def int? : Int32?
      parse do |bytes|
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
          return unless '0' <= char <= '9' # return on invalid character
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

    def line : String
      if @line
        line = String.new(@buffer)
        @buffer = Bytes.empty
        @token_size = 0
        line
      else
        error("End of file")
      end
    end

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
      
      def next_{{suffix.id}} : {{type}}
        next_token
        {{method.id}}
      end

      def next_{{suffix.id}}? : {{type}}?
        next_token
        {{method.id}}?
      end
    {% end %}

    def next_token : Bytes?
      return if @buffer.empty?

      @buffer += @token_size
      @token_size = 0
      ptr = @buffer.to_unsafe
      while ptr.value.unsafe_chr.ascii_whitespace?
        ptr += 1
      end
      @buffer += ptr - @buffer.to_unsafe
      until ptr.value == 0 || ptr.value.unsafe_chr.ascii_whitespace?
        ptr += 1
      end
      @token_size = (ptr - @buffer.to_unsafe).to_i

      current_token
    end

    def parse(& : Bytes -> T?) : T? forall T
      if token = current_token
        yield token
      end
    end

    def str : String
      str? || error("End of line")
    end

    def str? : String?
      parse do |bytes|
        String.new(bytes)
      end
    end

    private def current_token : Bytes?
      @buffer[0, @token_size] if @token_size > 0
    end

    private def location : Tuple(Int32, Int32, Int32)
      return {@line_number, 0, 0} unless line = @line
      column_number = @buffer.empty? ? line.bytesize : @buffer.to_unsafe - line.to_unsafe
      {@line_number, column_number.to_i, @token_size.to_i}
    end

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
