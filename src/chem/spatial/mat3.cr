module Chem::Spatial
  # A 3x3 matrix in row-major order. This is useful for encoding linear
  # maps such as scaling and rotation (see `Transform`).
  struct Mat3
    @buffer = uninitialized Float64[9]

    private def initialize; end # prevents uninitialized matrix

    # Returns a new 3x3 matrix using a matrix literal, i.e., three
    # indexable (array or tuple) literals.
    #
    # ```
    # Mat3[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    # ```
    macro [](*rows)
      {% if rows.size != 3 ||
              rows.any? { |r| !r.is_a?(TupleLiteral) && !r.is_a?(ArrayLiteral) } ||
              rows.any?(&.size.!=(3)) %}
        {% raise "Expected a matrix literal for #{@type}#[], not `Mat3[#{rows}]`)" %}
      {% end %}
      {{@type}}.build do |buffer|
        {% for i in 0..8 %}
          buffer[{{i}}] = {{rows[i // 3][i % 3]}}
        {% end %}
      end
    end

    # Returns the additive identity of the matrix (zero matrix).
    def self.additive_identity : self
      self.zero
    end

    # Returns a matrix in column-major order representing the basis
    # defined by the basis vectors.
    def self.basis(i : Vec3, j : Vec3, k : Vec3) : Spatial::Mat3
      Mat3[
        [i.x, j.x, k.x],
        [i.y, j.y, k.y],
        [i.z, j.z, k.z],
      ]
    end

    # Creates a new `Mat3`, allocating an internal buffer, and yielding
    # that buffer to the passed block.
    #
    # This method is **unsafe**, but is usually used to initialize the
    # buffer by other convenience methods without doing bounds check.
    def self.build(& : Pointer(Float64) ->) : self
      mat = new
      yield mat.to_unsafe
      mat
    end

    # Returns a new matrix with the diagonal set to *value*.
    def self.diagonal(value : Number) : self
      diagonal value, value, value
    end

    # Returns a new matrix with the elements at the diagonal set to the
    # given values.
    def self.diagonal(d1 : Number, d2 : Number, d3 : Number) : self
      Mat3.build do |buffer|
        buffer[0] = d1
        buffer[4] = d2
        buffer[8] = d3
      end
    end

    # Reads a matrix from *io* in the given *format*. See also:
    # `IO#read_bytes`.
    def self.from_io(io : IO, format : IO::ByteFormat) : self
      Mat3.build do |buffer|
        9.times do |i|
          buffer[i] = io.read_bytes(Float64, format)
        end
      end
    end

    # Returns the identity matrix.
    def self.identity : self
      Mat3.diagonal(1)
    end

    # Returns the multiplicative identity of the matrix (identity
    # matrix).
    def self.multiplicative_identity : self
      self.identity
    end

    # Returns the zero matrix.
    def self.zero : self
      Mat3.build do |buffer|
        buffer.clear(9)
      end
    end

    # Returns the row at *row*. Raises `IndexError` if *row* is out of
    # bounds.
    def [](row : Int, cols : Range(Nil, Nil)) : FloatTriple
      raise IndexError.new unless 0 <= row < 3
      offset = row * 3
      {unsafe_fetch(offset), unsafe_fetch(offset + 1), unsafe_fetch(offset + 2)}
    end

    # Returns the column at *col*. Raises `IndexError` if *col* is out
    # of bounds.
    def [](rows : Range(Nil, Nil), col : Int) : FloatTriple
      raise IndexError.new unless 0 <= col < 3
      {unsafe_fetch(col), unsafe_fetch(col + 3), unsafe_fetch(col + 6)}
    end

    # Returns the element at the given row and column. Raises
    # `IndexError` if indices are out of bounds.
    def [](row : Int, col : Int) : Float64
      raise IndexError.new unless 0 <= row < 3 && 0 <= col < 3
      unsafe_fetch(row, col)
    end

    # Returns the negation of the matrix.
    def - : self
      self * -1
    end

    {% begin %}
      {% op_map = {"+" => "addition", "-" => "subtraction"} %}
      {% for op in %w(+ -) %}
        {% op_name = op_map[op] %}
        # Returns the element-wise {{op_name.id}} of the matrix by *rhs*.
        def {{op.id}}(rhs : self) : self
          ptr = to_unsafe
          other = rhs.to_unsafe
          self.class.build do |buffer|
            {% for i in 0..8 %}
              buffer[{{i}}] = ptr[{{i}}] {{op.id}} other[{{i}}]
            {% end %}
          end
        end
      {% end %}
    {% end %}

    # Returns the element-wise multiplication of the matrix by *rhs*.
    def *(rhs : Number) : self
      map &.*(rhs)
    end

    # Returns the row-wise multiplication of the matrix by *rhs*.
    def *(rhs : NumberTriple) : self
      {% begin %}
        ptr = to_unsafe
        Mat3.build do |buffer|
          {% for i in 0..8 %}
            buffer[{{i}}] = ptr[{{i}}] * rhs.unsafe_fetch({{i // 3}})
          {% end %}
        end
      {% end %}
    end

    # Returns the multiplication of the matrix by *rhs*.
    def *(rhs : Vec3) : Vec3
      ptr = to_unsafe
      Vec3[
        ptr[0] * rhs.x + ptr[1] * rhs.y + ptr[2] * rhs.z,
        ptr[3] * rhs.x + ptr[4] * rhs.y + ptr[5] * rhs.z,
        ptr[6] * rhs.x + ptr[7] * rhs.y + ptr[8] * rhs.z,
      ]
    end

    # :ditto:
    def *(rhs : self) : self
      {% begin %}
        ptr = to_unsafe
        other = rhs.to_unsafe
        self.class.build do |buffer|
          {% for i in 0..2 %}
            {% for j in 0..2 %}
              buffer[{{i * 3 + j}}] = \
              {% for k in 0..2 %}
                ptr[{{i * 3 + k}}] * other[{{k * 3 + j}}] {{"+".id if k < 2}}
              {% end %}
            {% end %}
          {% end %}
        end
      {% end %}
    end

    # Returns the element-wise division of the matrix by *rhs*.
    def /(rhs : Number) : self
      map &./(rhs)
    end

    # Returns `true` if the elements of the matrices are close to each
    # other, else `false`. See the `#close_to?` method.
    def =~(other : self) : Bool
      close_to?(other)
    end

    # Returns `true` if the elements of the matrices are within *delta*
    # from each other, else `false`.
    def close_to?(rhs : self, delta : Float64 = Float64::EPSILON) : Bool
      (0..8).all? do |i|
        unsafe_fetch(i).close_to?(rhs.unsafe_fetch(i), delta)
      end
    end

    # Returns the determinant of the matrix.
    def det : Float64
      ptr = to_unsafe
      ptr[0] * ptr[4] * ptr[8] - ptr[0] * ptr[5] * ptr[7] -
        ptr[1] * ptr[3] * ptr[8] + ptr[1] * ptr[5] * ptr[6] +
        ptr[2] * ptr[3] * ptr[7] - ptr[2] * ptr[4] * ptr[6]
    end

    # Returns the inverse matrix. Raises `ArgumentError` if the matrix
    # is not invertible.
    #
    # The inverse matrix is computed using the Cramer's rule, which
    # states that `inv(A) = 1 / det(A) * adj(A)` provided that `det(A)
    # != 0`.
    def inv : self
      det = self.det
      raise ArgumentError.new("Matrix cannot be inverted") if det.close_to?(0)
      inv_det = 1 / det
      ptr = to_unsafe
      self.class.build do |buffer|
        buffer[0] = (ptr[4] * ptr[8] - ptr[5] * ptr[7]) * inv_det
        buffer[1] = (ptr[2] * ptr[7] - ptr[1] * ptr[8]) * inv_det
        buffer[2] = (ptr[1] * ptr[5] - ptr[2] * ptr[4]) * inv_det
        buffer[3] = (ptr[5] * ptr[6] - ptr[3] * ptr[8]) * inv_det
        buffer[4] = (ptr[0] * ptr[8] - ptr[2] * ptr[6]) * inv_det
        buffer[5] = (ptr[3] * ptr[2] - ptr[0] * ptr[5]) * inv_det
        buffer[6] = (ptr[3] * ptr[7] - ptr[6] * ptr[4]) * inv_det
        buffer[7] = (ptr[6] * ptr[1] - ptr[0] * ptr[7]) * inv_det
        buffer[8] = (ptr[0] * ptr[4] - ptr[3] * ptr[1]) * inv_det
      end
    end

    # Returns a new matrix with the results of the passed block for each
    # element in the matrix.
    def map(& : Float64 -> Float64) : self
      self.class.build do |buffer|
        9.times do |i|
          buffer[i] = yield unsafe_fetch(i)
        end
      end
    end

    # Returns an array with all the elements of the matrix.
    def to_a : Array(Float64)
      Array(Float64).build(9) do |buffer|
        buffer.copy_from @buffer.to_unsafe, 9
        9
      end
    end

    # Writes the binary representation of the matrix to *io* in the
    # given *format*. See also `IO#write_bytes`.
    def to_io(io : IO, format : IO::ByteFormat = :system_endian) : Nil
      @buffer.each do |value|
        io.write_bytes value, format
      end
    end

    def to_s(io : IO) : Nil
      format_spec = "%.#{PRINT_PRECISION}g"
      io << "["
      0.upto(2) do |i|
        io << "[ "
        0.upto(2) do |j|
          value = unsafe_fetch(i, j)
          io << (value >= 0 ? "  " : ' ') if j > 0
          io.printf format_spec, value
        end
        io << " ]"
        io << ", " if i < 2
      end
      io << ']'
    end

    # Returns a pointer to the internal buffer where the matrix elements
    # are stored.
    @[AlwaysInline]
    def to_unsafe : Pointer(Float64)
      @buffer.to_unsafe
    end

    # Returns the element at *row* and *col*, without doing any bounds
    # check.
    #
    # This should be called with *row* and *col* within `0...3`. Use
    # `#[](i, j)` and `#[]?(i, j)` instead for bounds checking and
    # support for negative indexes.
    #
    # NOTE: This method should only be directly invoked if you are
    # absolutely sure *row* and *col* are within bounds, to avoid a
    # bounds check for a small boost of performance.
    @[AlwaysInline]
    def unsafe_fetch(row : Int, col : Int) : Float64
      unsafe_fetch(row * 3 + col)
    end

    # Returns the element at the given index , without doing any bounds
    # check.
    #
    # NOTE: This method should only be directly invoked if you are
    # absolutely sure the index is within bounds, to avoid a bounds
    # check for a small boost of performance.
    @[AlwaysInline]
    def unsafe_fetch(index : Int) : Float64
      to_unsafe[index]
    end
  end
end
