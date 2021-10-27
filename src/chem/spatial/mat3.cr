module Chem::Spatial
  # A 3x3 matrix in row-major order. This is useful for encoding linear
  # maps such as scaling and rotation (see `AffineTransform`).
  struct Mat3
    @buffer : Tuple(FloatTriple, FloatTriple, FloatTriple)

    # Creates a new matrix with the given rows.
    def initialize(r1 : FloatTriple, r2 : FloatTriple, r3 : FloatTriple)
      @buffer = {r1, r2, r3}
    end

    # Returns a new matrix with the given rows.
    @[AlwaysInline]
    def self.[](r1 : NumberTriple, r2 : NumberTriple, r3 : NumberTriple) : self
      Mat3.new(r1.map(&.to_f), r2.map(&.to_f), r3.map(&.to_f))
    end

    # Returns the additive identity of the matrix (zero matrix).
    def self.additive_identity : self
      self.zero
    end

    # Returns a new matrix with the diagonal set to *value*.
    def self.diagonal(value : Number) : self
      diagonal value, value, value
    end

    # Returns a new matrix with the elements at the diagonal set to the
    # given values.
    def self.diagonal(d1 : Number, d2 : Number, d3 : Number) : self
      Mat3[
        {d1, 0, 0},
        {0, d2, 0},
        {0, 0, d3},
      ]
    end

    # Returns the identity matrix.
    def self.identity : self
      Mat3[
        {1, 0, 0},
        {0, 1, 0},
        {0, 0, 1},
      ]
    end

    # Returns the multiplicative identity of the matrix (identity
    # matrix).
    def self.multiplicative_identity : self
      self.identity
    end

    # Returns the zero matrix.
    def self.zero : self
      Mat3[
        {0, 0, 0},
        {0, 0, 0},
        {0, 0, 0},
      ]
    end

    # Returns the row at *index*. Raises `IndexError` if *index* is out
    # of bounds.
    def [](index : Int) : FloatTriple
      @buffer[index]
    end

    # Returns the element at row *i* and column *j*. Raises `IndexError`
    # if indices are out of bounds.
    def [](i : Int, j : Int) : Float64
      self[i][j]
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
          Mat3[
            {% for i in 0..2 %}
              {
                {% for j in 0..2 %}
                  self[{{i}}, {{j}}] {{op.id}} rhs[{{i}}, {{j}}],
                {% end %}
              },
            {% end %}
          ]
        end
      {% end %}
    {% end %}

    # Returns the element-wise multiplication of the matrix by *rhs*.
    def *(rhs : Number) : self
      Mat3.new *@buffer.map { |row| row.map(&.*(rhs)) }
    end

    # Returns the row-wise multiplication of the matrix by *rhs*.
    def *(rhs : NumberTriple) : self
      Mat3.new *@buffer.map_with_index { |row, i| row.map(&.*(rhs[i])) }
    end

    # Returns the multiplication of the matrix by *rhs*.
    def *(rhs : Vec3) : Vec3
      {% begin %}
        Vec3[
          {% for i in 0..2 %}
            {% for j in 0..2 %}
              self[{{i}}, {{j}}] * rhs[{{j}}] {{(j < 2 ? "+" : ",").id}}
            {% end %}
          {% end %}
        ]
      {% end %}
    end

    # :ditto:
    def *(rhs : self) : self
      {% begin %}
        Mat3[
          {% for i in 0..2 %}
            {
              {% for j in 0..2 %}
                {% for k in 0..2 %}
                  self[{{i}}, {{k}}] * rhs[{{k}}, {{j}}] {{(k < 2 ? "+" : ",").id}}
                {% end %}
              {% end %}
            },
          {% end %}
        ]
      {% end %}
    end

    # Returns the element-wise division of the matrix by *rhs*.
    def /(rhs : Number) : self
      Mat3.new *@buffer.map { |row| row.map(&./(rhs)) }
    end

    # Returns `true` if the elements of the matrices are within *delta*
    # from each other, else `false`.
    def close_to?(rhs : self, delta : Float64 = Float64::EPSILON) : Bool
      (0..2).all? do |i|
        (0..2).all? do |j|
          self[i, j].close_to?(rhs[i, j], delta)
        end
      end
    end

    # Returns the determinant of the matrix.
    def det : Float64
      self[0, 0] * self[1, 1] * self[2, 2] - self[0, 0] * self[1, 2] * self[2, 1] -
        self[0, 1] * self[1, 0] * self[2, 2] + self[0, 1] * self[1, 2] * self[2, 0] +
        self[0, 2] * self[1, 0] * self[2, 1] - self[0, 2] * self[1, 1] * self[2, 0]
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
      Mat3[
        {
          (self[1, 1] * self[2, 2] - self[1, 2] * self[2, 1]) * inv_det,
          (self[0, 2] * self[2, 1] - self[0, 1] * self[2, 2]) * inv_det,
          (self[0, 1] * self[1, 2] - self[0, 2] * self[1, 1]) * inv_det,
        },
        {
          (self[1, 2] * self[2, 0] - self[1, 0] * self[2, 2]) * inv_det,
          (self[0, 0] * self[2, 2] - self[0, 2] * self[2, 0]) * inv_det,
          (self[1, 0] * self[0, 2] - self[0, 0] * self[1, 2]) * inv_det,
        },
        {
          (self[1, 0] * self[2, 1] - self[2, 0] * self[1, 1]) * inv_det,
          (self[2, 0] * self[0, 1] - self[0, 0] * self[2, 1]) * inv_det,
          (self[0, 0] * self[1, 1] - self[1, 0] * self[0, 1]) * inv_det,
        },
      ]
    end

    def to_s(io : IO) : Nil
      format_spec = "%.#{PRINT_PRECISION}g"
      io << "["
      0.upto(2) do |i|
        io << "[ "
        0.upto(2) do |j|
          io << (self[i, j] >= 0 ? "  " : ' ') if j > 0
          io.printf format_spec, self[i, j]
        end
        io << " ]"
        io << ", " if i < 2
      end
      io << ']'
    end
  end
end
