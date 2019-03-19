module Chem::Linalg
  # A `Matrix` is a rectangular array of numbers, arranged in rows and columns.
  #
  # It behaves similar to an `Array`, but items are accessed by two indexes: row and
  # column. Similar to `Array`, array indexing starts at 0. A negative index is assumed
  # to be relative to the end of the row/column: -1 indicates the last element, -2 is
  # the second to last element, and so on.
  #
  # There are several convenience methods to create a `Matrix` (see below), but using
  # the `[]` short-hand method is the most common:
  #
  # ```
  # require "chem"
  # alias M = Chem::Linalg::Matrix # avoid repeating the full name
  # M[[0, 1, 2], [3, 4, 5]]        # => Matrix[[0, 1, 2], [3, 4, 5]]
  # ```
  #
  # This partial implementation is heavily based on the original `Matrix` code in the
  # standard library, which was then moved to a shard (currently available at
  # [github.com/Exilor/matrix](https://github.com/Exilor/matrix)).
  #
  # NOTE: numbers are internally saved in double precision floating-point format. NOTE:
  # The implementation of some methods may be too slow for big matrices. In such cases,
  # it is suggested to use a specialized library that leverages low-level optimized
  # linear algebra packages such as BLAS/LAPACK
  class Matrix
    @buffer : Pointer(Float64)

    getter columns : Int32
    getter rows : Int32
    getter size : Int32 { @rows * @columns }

    def initialize(@rows : Int32, @columns : Int32, initial_value : Float64? = nil)
      @buffer = if value = initial_value
                  Pointer(Float64).malloc size, value
                else
                  Pointer(Float64).malloc size
                end
    end

    def initialize(@rows : Int32,
                   @columns : Int32,
                   &block : Int32, Int32, Int32 -> Number::Primitive)
      @buffer = Pointer(Float64).malloc(size) do |k|
        i = k / @columns
        j = k % @columns
        (yield i, j, k).to_f
      end
    end

    def self.[](*rows : Indexable(Number)) : self
      if rows.all? { |row| row.size == rows.first.size }
        Matrix.new(rows.size, rows.first.size) { |i, j| rows[i][j] }
      else
        raise Error.new "Rows have different sizes"
      end
    end

    def self.column(*values : Number) : self
      Matrix.new(values.size, 1) { |i| values[i] }
    end

    def self.diagonal(size : Int, initial_value : Float64) : self
      m = Matrix.square size
      size.times { |i| m[i, i] = initial_value }
      m
    end

    def self.diagonal(size : Int, &block : Int32 -> Number::Primitive) : self
      m = Matrix.square size
      size.times { |i| m[i, i] = (yield i).to_f }
      m
    end

    def self.diagonal(*values : Number) : self
      m = Matrix.square values.size
      values.each_with_index do |value, i|
        m[i, i] = value.to_f
      end
      m
    end

    def self.identity(size : Int) : self
      diagonal size, initial_value: 1
    end

    def self.square(size : Int, initial_value : Float64? = nil) : self
      Matrix.new size, size, initial_value
    end

    def self.square(size : Int, &block : Int32, Int32 -> Number::Primitive) : self
      Matrix.new size, size, &block
    end

    def [](i : Int, j : Int) : Float64
      self[i, j]? || raise IndexError.new
    end

    def []?(i : Int, j : Int) : Float64?
      if k = internal_index?(i, j)
        unsafe_fetch k
      else
        nil
      end
    end

    @[AlwaysInline]
    protected def []=(index : Int32, value : Float64) : Float64
      @buffer[index] = value
    end

    def []=(i : Int, j : Int, value : Float64) : Float64
      if k = internal_index?(i, j)
        self[unsafe_internal_index(i, j)] = value
      else
        raise IndexError.new
      end
    end

    {% for op in %i(+ - * /) %}
      def {{op.id}}(other : Number) : self
        map &.{{op.id}}(other)
      end
    {% end %}

    {% for op in %i(+ -) %}
      def {{op.id}}(other : self) : self
        raise Error.new "Matrices have different dimensions" if dim != other.dim
        map_with_index do |value, _, _, k|
          value {{op.id}} other.unsafe_fetch(k)
        end
      end
    {% end %}

    def *(other : self) : self
      raise Error.new "Matrices have incompatible dimensions" if columns != other.rows
      Matrix.new(rows, other.columns) do |i, j|
        i = i * @columns
        (0...@columns).sum do |d|
          unsafe_fetch(i + d) * other.unsafe_fetch(d, j)
        end
      end
    end

    def ==(other : self) : Bool
      return false if dim != other.dim
      (0...size).all? do |i|
        unsafe_fetch(i) == other.unsafe_fetch(i)
      end
    end

    def det : Float64
      raise Error.new "Cannot compute the determinant of a non-square matrix" unless square?
      case @rows
      when 0
        1.0
      when 1
        unsafe_fetch 0
      when 2
        unsafe_fetch(0) * unsafe_fetch(3) - unsafe_fetch(1) * unsafe_fetch(2)
      when 3
        unsafe_fetch(0) * unsafe_fetch(4) * unsafe_fetch(8) -
          unsafe_fetch(0) * unsafe_fetch(5) * unsafe_fetch(7) -
          unsafe_fetch(1) * unsafe_fetch(3) * unsafe_fetch(8) +
          unsafe_fetch(1) * unsafe_fetch(5) * unsafe_fetch(6) +
          unsafe_fetch(2) * unsafe_fetch(3) * unsafe_fetch(7) -
          unsafe_fetch(2) * unsafe_fetch(4) * unsafe_fetch(6)
      when 4
        unsafe_fetch(0) * unsafe_fetch(5) * unsafe_fetch(10) * unsafe_fetch(15) -
          unsafe_fetch(0) * unsafe_fetch(5) * unsafe_fetch(11) * unsafe_fetch(14) -
          unsafe_fetch(0) * unsafe_fetch(6) * unsafe_fetch(9) * unsafe_fetch(15) +
          unsafe_fetch(0) * unsafe_fetch(6) * unsafe_fetch(11) * unsafe_fetch(13) +
          unsafe_fetch(0) * unsafe_fetch(7) * unsafe_fetch(9) * unsafe_fetch(14) -
          unsafe_fetch(0) * unsafe_fetch(7) * unsafe_fetch(10) * unsafe_fetch(13) -
          unsafe_fetch(1) * unsafe_fetch(4) * unsafe_fetch(10) * unsafe_fetch(15) +
          unsafe_fetch(1) * unsafe_fetch(4) * unsafe_fetch(11) * unsafe_fetch(14) +
          unsafe_fetch(1) * unsafe_fetch(6) * unsafe_fetch(8) * unsafe_fetch(15) -
          unsafe_fetch(1) * unsafe_fetch(6) * unsafe_fetch(11) * unsafe_fetch(12) -
          unsafe_fetch(1) * unsafe_fetch(7) * unsafe_fetch(8) * unsafe_fetch(14) +
          unsafe_fetch(1) * unsafe_fetch(7) * unsafe_fetch(10) * unsafe_fetch(12) +
          unsafe_fetch(2) * unsafe_fetch(4) * unsafe_fetch(9) * unsafe_fetch(15) -
          unsafe_fetch(2) * unsafe_fetch(4) * unsafe_fetch(11) * unsafe_fetch(13) -
          unsafe_fetch(2) * unsafe_fetch(5) * unsafe_fetch(8) * unsafe_fetch(15) +
          unsafe_fetch(2) * unsafe_fetch(5) * unsafe_fetch(11) * unsafe_fetch(12) +
          unsafe_fetch(2) * unsafe_fetch(7) * unsafe_fetch(8) * unsafe_fetch(13) -
          unsafe_fetch(2) * unsafe_fetch(7) * unsafe_fetch(9) * unsafe_fetch(12) -
          unsafe_fetch(3) * unsafe_fetch(4) * unsafe_fetch(9) * unsafe_fetch(14) +
          unsafe_fetch(3) * unsafe_fetch(4) * unsafe_fetch(10) * unsafe_fetch(13) +
          unsafe_fetch(3) * unsafe_fetch(5) * unsafe_fetch(8) * unsafe_fetch(14) -
          unsafe_fetch(3) * unsafe_fetch(5) * unsafe_fetch(10) * unsafe_fetch(12) -
          unsafe_fetch(3) * unsafe_fetch(6) * unsafe_fetch(8) * unsafe_fetch(13) +
          unsafe_fetch(3) * unsafe_fetch(6) * unsafe_fetch(9) * unsafe_fetch(12)
      else
        mat = dup
        last = @rows - 1
        sign = 1.0
        pivot = 1.0
        @rows.times do |k|
          previous_pivot = pivot
          if (pivot = mat.unsafe_fetch(k, k)) == 0
            swap_row = ((k + 1)...@rows).find(0) { |i| mat.unsafe_fetch(i, k) != 0 }
            mat.swap_rows swap_row, k
            pivot = mat.unsafe_fetch k, k
            sign = -sign
          end

          (k + 1).upto(last) do |i|
            (k + 1).upto(last) do |j|
              ij = unsafe_internal_index i, j
              ik = unsafe_internal_index i, k
              kj = unsafe_internal_index k, j
              mat[ij] = (pivot * mat.unsafe_fetch(ij) - mat.unsafe_fetch(ik) * mat.unsafe_fetch(kj)) / previous_pivot
            end
          end
        end
        sign * pivot
      end
    end

    def dim : Tuple(Int32, Int32)
      {@rows, @columns}
    end

    def dup : self
      Matrix.new(@rows, @columns) do |_, _, k|
        unsafe_fetch k
      end
    end

    def each_with_index : Iterator(Tuple(Float64, Int32, Int32))
      ItemWithIndexIterator.new self
    end

    def each_with_index(&block : Float64, Int32, Int32 ->)
      k = 0
      while k < size
        i = k / @columns
        j = k % @columns
        yield unsafe_fetch(k), i, j
        k += 1
      end
    end

    def inspect(io : ::IO)
      io << "Matrix[["
      each_with_index do |value, i, j|
        io << (j == 0 ? "], [" : ", ") if i > 0 || j > 0
        value.inspect io
      end
      io << "]]"
    end

    def inv : self
      raise Error.new "Non-square matrix is not invertible" unless square?
      last = @rows - 1
      mat, inv_mat = dup, Matrix.new(@rows, @columns) { |i, j| i == j ? 1 : 0 }

      0.upto(last) do |k|
        i = k
        akk = mat.unsafe_fetch(k, k).abs
        (k + 1).upto(last) do |j|
          v = mat.unsafe_fetch(j, k).abs
          if v > akk
            i = j
            akk = v
          end
        end

        raise Error.new if akk == 0

        if i != k
          mat.swap_rows i, k
          inv_mat.swap_rows i, k
        end

        akk = mat.unsafe_fetch k, k
        0.upto(last) do |ii|
          next if ii == k
          q = mat.unsafe_fetch(ii, k) / akk
          mat[unsafe_internal_index(ii, k)] = 0.0
          (k + 1).upto(last) do |j|
            ui = unsafe_internal_index ii, j
            mat[ui] = mat.unsafe_fetch(ui) - mat.unsafe_fetch(k, j) * q
          end

          0.upto(last) do |j|
            ui = unsafe_internal_index ii, j
            inv_mat[ui] = inv_mat.unsafe_fetch(ui) - inv_mat.unsafe_fetch(k, j) * q
          end
        end

        (k + 1).upto(last) do |j|
          mat[unsafe_internal_index(k, j)] = mat.unsafe_fetch(k, j) / akk
        end

        0.upto(last) do |j|
          inv_mat[unsafe_internal_index(k, j)] = inv_mat.unsafe_fetch(k, j) / akk
        end
      end

      inv_mat
    end

    private def internal_index?(i : Int32, j : Int32) : Int32?
      i += @rows if i < 0
      j += @columns if j < 0
      unsafe_internal_index i, j if 0 <= i < @rows && 0 <= j < @columns
    end

    def map(&block : Float64 -> Float64) : self
      Matrix.new(@rows, @columns) do |_, _, k|
        yield unsafe_fetch(k)
      end
    end

    def map_with_index(&block : Float64, Int32, Int32, Int32 -> Float64) : self
      Matrix.new(@rows, @columns) do |i, j, k|
        yield unsafe_fetch(k), i, j, k
      end
    end

    def singular? : Bool
      det == 0
    end

    def square? : Bool
      @rows == @columns
    end

    def swap_rows(i1 : Int, i2 : Int) : self
      unless i1 == i2
        i1 += @rows if i1 < 0
        i2 += @rows if i2 < 0
        raise IndexError.new unless i1 < @rows && i2 < @rows
        @columns.times do |j|
          value = unsafe_fetch i1, j
          @buffer[unsafe_internal_index(i1, j)] = unsafe_fetch i2, j
          @buffer[unsafe_internal_index(i2, j)] = value
        end
      end
      self
    end

    def to_a : Array(Array(Float64))
      ary = Array(Array(Float64)).new @rows { Array(Float64).new @columns }
      each_with_index do |value, i|
        ary[i] << value
      end
      ary
    end

    def to_s(io : ::IO)
      io << "[["
      each_with_index do |value, i, j|
        io << (j == 0 ? "]\n [" : " ") if i > 0 || j > 0
        value.to_s io
      end
      io << "]]"
    end

    def to_vector : Spatial::Vector
      raise Error.new "Matrix is not a column vector" unless dim == {3, 1}
      Spatial::Vector.new unsafe_fetch(0), unsafe_fetch(1), unsafe_fetch(2)
    end

    @[AlwaysInline]
    protected def unsafe_fetch(index : Int) : Float64
      @buffer[index]
    end

    @[AlwaysInline]
    def unsafe_fetch(i : Int32, j : Int32) : Float64
      unsafe_fetch unsafe_internal_index(i, j)
    end

    @[AlwaysInline]
    private def unsafe_internal_index(i : Int32, j : Int32) : Int32
      i * @columns + j
    end

    private class ItemWithIndexIterator
      include Iterator(Tuple(Float64, Int32, Int32))

      def initialize(@matrix : Matrix, @i = 0, @j = 0)
      end

      def next
        if @i < @matrix.rows && @j < @matrix.columns
          value = {@matrix.unsafe_fetch(@i, @j), @i, @j}
          @j += 1
          if @j == @matrix.columns
            @i += 1
            @j = 0
          end
          value
        else
          stop
        end
      end

      def rewind
        @i = @j = 0
        self
      end
    end
  end
end
