require "../spec_helper"

alias M = Chem::Linalg::Matrix

describe Chem::Linalg::Matrix do
  describe ".[]" do
    it "creates a matrix" do
      M[[1, 2], [3, 4], [5, 6]].to_a.should eq [[1, 2], [3, 4], [5, 6]]
    end

    it "fails with rows of different size" do
      expect_raises Chem::Linalg::Error, "Rows have different sizes" do
        M[[1, 2], [3, 4, 5]]
      end
    end
  end

  describe ".column" do
    it "creates a column matrix" do
      M.column(1, 2, 3).should eq M[[1], [2], [3]]
    end
  end

  describe ".diagonal" do
    it "creates a square matrix with the main diagonal set to an initial value" do
      M.diagonal(3, initial_value: 8).to_a.should eq [[8, 0, 0], [0, 8, 0], [0, 0, 8]]
    end

    it "creates a square matrix with the main diagonal set to initial values from block" do
      M.diagonal(3) { |i| i ** 2 }.to_a.should eq [[0, 0, 0], [0, 1, 0], [0, 0, 4]]
    end

    it "creates a square matrix with the main diagonal set to the given values" do
      M.diagonal(1, 2, 3).to_a.should eq [[1, 0, 0], [0, 2, 0], [0, 0, 3]]
    end
  end

  describe ".identity" do
    it "creates a square matrix with the main diagonal set to one" do
      M.identity(3).to_a.should eq([[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    end
  end

  describe ".square" do
    it "creates a square matrix" do
      M.square(2).to_a.should eq [[0, 0], [0, 0]]
    end

    it "creates a square matrix with an initial value" do
      M.square(2, initial_value: 8).to_a.should eq [[8, 8], [8, 8]]
    end

    it "creates a square matrix with initial values from block" do
      M.square(2) { |i, j| i*j }.to_a.should eq [[0, 0], [0, 1]]
    end
  end

  describe "#+" do
    it "adds a matrix and a number" do
      (M.square(2) + 3.5).should eq M[[3.5, 3.5], [3.5, 3.5]]
    end

    it "adds two matrices" do
      a = M[[1, 2], [3, 4], [5, 6], [7, 8]]
      b = M[[2, 4], [6, 8], [10, 12], [14, 16]]
      (a + a).should eq b
    end

    it "raises when matrices have different dimensions" do
      expect_raises Chem::Linalg::Error, "Matrices have different dimensions" do
        M.square(5) + M.new(3, 4)
      end
    end
  end

  describe "#-" do
    it "substracts a number from a matrix" do
      (M.diagonal(1, 2) - 2).should eq M[[-1, -2], [-2, 0]]
    end

    it "subtracts two matrices" do
      a = M[[1, 2], [3, 4], [5, 6], [7, 8]]
      b = M[[2, 4], [6, 8], [10, 12], [14, 16]]
      c = M[[-1, -2], [-3, -4], [-5, -6], [-7, -8]]
      (a - b).should eq(c)
    end

    it "fails when matrices have different dimensions" do
      expect_raises Chem::Linalg::Error, "Matrices have different dimensions" do
        M.new(4, 3) - M.new(3, 4)
      end
    end
  end

  describe "#*" do
    it "multiplies a matrix by a number" do
      (M[[1, 2, 3], [4, 5, 6]] * 2.5).should eq M[[2.5, 5, 7.5], [10, 12.5, 15]]
    end

    it "multiplies two matrices" do
      a = M[[1, 2], [3, 4]]
      b = M[[5, 6], [7, 8]]
      (a * b).should eq M[[19, 22], [43, 50]]
    end

    it "multiplies two matrices with different dimensions" do
      a = M[[2, 3, 4], [1, 0, 0]]
      b = M[[0, 1000], [1, 100], [0, 10]]
      (a * b).should eq M[[3, 2340], [0, 1000]]
    end

    it "fails when matrices have incompatible dimensions" do
      expect_raises Chem::Linalg::Error, "Matrices have incompatible dimensions" do
        M.new(2, 4) * M.new(3, 4)
      end
    end
  end

  describe "#/" do
    it "divides a matrix by a number" do
      (M[[2, 4, 6]] / 2).should eq M[[1, 2, 3]]
    end

    #   it "does division with another matrix (1)" do
    #     a = Matrix[[7, 6], [3, 9]]
    #     b = Matrix[[2, 9], [3, 1]]
    #     c = Matrix[["0.44", "2.04"], ["0.96", "0.36"]]
    #     (a / b).map(&.to_s).should eq(c)
    #   end

    #   it "does division with another matrix (2)" do
    #     a = Matrix[[7, 6], [3, 9]]
    #     b = Matrix[[1, 0], [0, 1]]
    #     (a / a).map(&.round).should eq(b)
    #   end

    #   it "does division with another matrix (3)" do
    #     a = Matrix[[1, 2, 3], [3, 2, 1], [2, 1, 3]]
    #     b = Matrix[[1, 2, 1], [2, 0, 4], [2, 1, 3]]
    #     c = Matrix[[3, 3, -4],
    #       [-3, -5, 8],
    #       [0, 0, 1]]
    #     (a / b).should eq(c)
    #   end
  end

  describe "#each_with_index" do
    it "iterates over each value together with its row and column indexes" do
      it = M.new(3, 2) { |_, _, k| k**2 }.each_with_index
      it.next.should eq({0, 0, 0})
      it.next.should eq({1, 0, 1})
      it.next.should eq({4, 1, 0})
      it.next.should eq({9, 1, 1})
      it.next.should eq({16, 2, 0})
      it.next.should eq({25, 2, 1})
      it.next.should eq Iterator.stop
    end

    it "iterates over each value together with its row and column indexes (block)" do
      ary = [] of Tuple(Float64, Int32, Int32)
      M.diagonal(3, 1).each_with_index do |value, i, j|
        ary << {value, i, j}
      end
      ary.should eq [{3, 0, 0}, {0, 0, 1}, {0, 1, 0}, {1, 1, 1}]
    end
  end

  describe "#det" do
    it "computes the determinant of the matrix (0x0)" do
      M.new(0, 0).det.should eq 1
    end

    it "computes the determinant of the matrix (1x1)" do
      M[[3]].det.should eq 3
    end

    it "computes the determinant of the matrix (2x2)" do
      M[[4, 6], [3, 8]].det.should eq 14
    end

    it "computes the determinant of the matrix (3x3)" do
      M[[6, 1, 1], [4, -2, 5], [2, 8, 7]].det.should eq -306
    end

    it "computes the determinant of the matrix (4x4)" do
      mat = M[[13.18570568, 6.79602198, 5.09829199, 14.15936519],
        [18.638476, 11.91565457, 18.44070702, 9.13247453],
        [10.56454134, 5.10607615, 10.37425495, 16.50457539],
        [13.03516397, 16.4795491, 11.23097343, 14.50417697]]
      mat.det.should be_close 15720.84467553, 1e-8
    end

    it "computes the determinant of the matrix (bigger)" do
      mat = M[
        [8.34214e+08, 1.49162e+09, 1.73546e+09, 1.92257e+09, 9.61509e+08],
        [4.65819e+08, 1.10092e+09, 2.57361e+08, 9.85276e+08, 5.04763e+08],
        [2.63287e+08, 5.28931e+08, 1.39454e+09, 1.52471e+09, 4.30514e+08],
        [2.02314e+09, 1.92594e+08, 7.72298e+08, 1.72581e+09, 2.05689e+09],
        [7.35774e+08, 1.71179e+09, 9.40757e+08, 9.72277e+08, 1.46371e+09]]
      mat.det.should be_close 1.25922e+45, 1e40
    end

    it "fails when matrix is not square" do
      expect_raises Chem::Linalg::Error, "Cannot compute the determinant of a non-square matrix" do
        M.new(4, 3).det
      end
    end
  end

  describe "#dup" do
    it "returns a copy of the matrix" do
      mat = M.new(4, 3) { |_, _, k| k**2 }
      mat.dup.should_not be mat
      mat.dup.should eq mat
    end
  end

  describe "#inspect" do
    it "returns a string representation of the matrix" do
      M.diagonal(5, 3).inspect.should eq "Matrix[[5.0, 0.0], [0.0, 3.0]]"
    end
  end

  describe "#inverse" do
    it "returns the inverse of the matrix" do
      M[[-1, -1], [0, -1]].inv.should eq M[[-1, 1], [0, -1]]
      M[[4, 3], [3, 2]].inv.should eq M[[-2, 3], [3, -4]]
      M[[4, 7], [2, 6]].inv.should eq M[[0.6, -0.7], [-0.2, 0.4]]

      mat = M[
        [0, 1, 2, 6],
        [8, 9, 7, 2],
        [3, 2, 2, 3],
        [9, 9, 1, 9]]
      inv_mat = M[
        [-0.26860841, -0.10194175, 0.62944984, -0.00809061],
        [0.14563107, 0.14563107, -0.70873786, 0.10679612],
        [0.08737864, 0.08737864, 0.17475728, -0.13592233],
        [0.11326861, -0.05339806, 0.05987055, 0.02750809]]
      mat.inv.should be_close inv_mat, 1e-8
    end
  end

  describe "#map" do
    it "returns a new matrix with the values from block" do
      M.identity(3).map(&.*(3)).should eq M[[3, 0, 0], [0, 3, 0], [0, 0, 3]]
    end
  end

  describe "#map_with_index" do
    it "returns a new matrix with the values from block" do
      mat = M.new(3, 3) { |_, _, k| k + 1 }
        .map_with_index { |value, i, j| i * 100 + j * 10 + value }
      mat.should eq M[[1, 12, 23], [104, 115, 126], [207, 218, 229]]
    end
  end

  describe "#reshape" do
    it "returns a new matrix with the given dimensions" do
      mat = M.square(2) { |i, j| i * 10 + j + 1 }
      new_mat = mat.reshape(4, 1)
      new_mat.should_not be mat
      new_mat.should eq M[[1], [2], [11], [12]]
    end

    it "fails when the new dimensions are incompatible" do
      expect_raises Chem::Linalg::Error, "Can't reshape a matrix with dimensions (2, 2) to (3, 1)" do
        M.square(2).reshape 3, 1
      end
    end
  end

  describe "#reshape!" do
    it "changes the dimensions of the matrix" do
      mat = M.square(2) { |i, j| i * 10 + j + 1 }
      new_mat = mat.reshape!(4, 1)
      new_mat.should be mat
      new_mat.should eq M[[1], [2], [11], [12]]
    end

    it "fails when the new dimensions are incompatible" do
      expect_raises Chem::Linalg::Error, "Can't reshape a matrix with dimensions (3, 3) to (2, 4)" do
        M.square(3).reshape! 2, 4
      end
    end
  end

  describe "#resize" do
    it "returns a shrinked matrix" do
      mat = M[[0, 1], [2, 3]]
      other = mat.resize 2, 1
      other.should_not be mat
      other.dim.should eq({2, 1})
      mat.should eq M[[0, 1], [2, 3]]
      other.should eq M[[0], [2]]
    end

    it "returns an enlarged matrix" do
      mat = M[[4], [5]]
      other = mat.resize 3, 4
      other.should_not be mat
      other.dim.should eq ({3, 4})
      mat.should eq M[[4], [5]]
      other.should eq M[[4, 0, 0, 0], [5, 0, 0, 0], [0, 0, 0, 0]]
    end

    it "returns an enlarged matrix with missing entries filled with the given value" do
      mat = M[[0, 1], [2, 3]]
      other = mat.resize 2, 3, fill_value: 3.5
      other.should_not be mat
      other.dim.should eq ({2, 3})
      mat.should eq M[[0, 1], [2, 3]]
      other.should eq M[[0, 1, 3.5], [2, 3, 3.5]]
    end
  end

  describe "#resize!" do
    it "shrinks a matrix" do
      mat = M[[0, 1], [2, 3]]
      mat.resize! 2, 1
      mat.dim.should eq({2, 1})
      mat.should eq M[[0], [2]]
    end

    it "enlarges a matrix" do
      mat = M[[4], [5]]
      mat.resize! 3, 4
      mat.dim.should eq ({3, 4})
      mat.should eq M[[4, 0, 0, 0], [5, 0, 0, 0], [0, 0, 0, 0]]
    end

    it "enlarges a matrix with missing entries filled with the given value" do
      mat = M[[0, 1], [2, 3]]
      mat.resize! 2, 3, fill_value: 3.5
      mat.dim.should eq ({2, 3})
      mat.should eq M[[0, 1, 3.5], [2, 3, 3.5]]
    end
  end

  describe "#singular?" do
    it "returns true when the matrix is singular" do
      M[[2, 6], [1, 3]].singular?.should be_true
      M[[1, 2, 3], [4, 5, 6], [7, 8, 9]].singular?.should be_true
    end

    it "returns false when the matrix is not singular" do
      M[[1, 2], [3, 4]].singular?.should be_false
    end
  end

  describe "#square?" do
    it "returns true when matrix is square" do
      M.new(4, 4).square?.should be_true
    end

    it "returns false when matrix is not square" do
      M.new(3, 4).square?.should be_false
    end
  end

  describe "#swap_rows" do
    it "swaps two rows" do
      mat = M.new(3, 4) { |_, _, k| k + 1 }
      mat.swap_rows(0, 2).should eq M[[9, 10, 11, 12], [5, 6, 7, 8], [1, 2, 3, 4]]
    end

    it "fails on invalid row index" do
      expect_raises IndexError do
        M.new(3, 4).swap_rows 0, 5
      end
    end
  end

  describe "#to_a" do
    it "returns an array with the contents of the matrix" do
      M.identity(3).to_a.should eq [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    end
  end

  describe "#to_s" do
    it "returns the string representation of the matrix" do
      M.identity(3).to_s.should eq <<-EOS
      [[1.0 0.0 0.0]
       [0.0 1.0 0.0]
       [0.0 0.0 1.0]]
      EOS
    end
  end

  describe "#to_vector" do
    it "returns a vector" do
      M.column(1, 2, 3).to_vector.should eq V[1, 2, 3]
    end

    it "fails when matrix is not a column vector" do
      expect_raises Chem::Linalg::Error, "Matrix is not a column vector" do
        M.new(3, 2).to_vector
      end
    end
  end
end
