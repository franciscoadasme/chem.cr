require "../spec_helper"

describe Chem::Spatial::Mat3 do
  describe ".[]" do
    it "returns a matrix with the given values" do
      mat = Chem::Spatial::Mat3[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      (0..8).map { |i| mat.unsafe_fetch(i) }.should eq (1..9).to_a
    end
  end

  describe ".additive_identity" do
    it "returns the zero matrix" do
      Chem::Spatial::Mat3.additive_identity.should eq Chem::Spatial::Mat3.zero
    end
  end

  describe ".basis" do
    it "returns a basis matrix" do
      Chem::Spatial::Mat3.basis(vec3(1, 2, 3), vec3(4, 5, 6), vec3(7, 8, 9)).should eq Chem::Spatial::Mat3[
        {1, 4, 7},
        {2, 5, 8},
        {3, 6, 9},
      ]
    end
  end

  describe ".identity" do
    it "returns the identity matrix" do
      Chem::Spatial::Mat3.identity.should eq Chem::Spatial::Mat3[{1, 0, 0}, {0, 1, 0}, {0, 0, 1}]
    end
  end

  describe ".multiplicative_identity" do
    it "returns the identity matrix" do
      Chem::Spatial::Mat3.multiplicative_identity.should eq Chem::Spatial::Mat3.identity
    end
  end

  describe ".zero" do
    it "returns the zero matrix" do
      Chem::Spatial::Mat3.zero.should eq Chem::Spatial::Mat3[{0, 0, 0}, {0, 0, 0}, {0, 0, 0}]
    end
  end

  describe "#[]" do
    it "returns the given row" do
      mat = Chem::Spatial::Mat3[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      mat[0, ..].should eq({1, 2, 3})
      mat[1, ..].should eq({4, 5, 6})
      mat[2, ..].should eq({7, 8, 9})
    end

    it "returns the given column" do
      mat = Chem::Spatial::Mat3[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      mat[.., 0].should eq({1, 4, 7})
      mat[.., 1].should eq({2, 5, 8})
      mat[.., 2].should eq({3, 6, 9})
    end

    it "raises if index is out of bounds" do
      expect_raises(IndexError) { Chem::Spatial::Mat3.zero[3, ..] }
      expect_raises(IndexError) { Chem::Spatial::Mat3.zero[.., 20] }
    end

    it "returns the given element" do
      mat = Chem::Spatial::Mat3[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      mat[0, 0].should eq 1
      mat[2, 1].should eq 8
    end

    it "raises if indexes are out of bounds" do
      expect_raises IndexError do
        Chem::Spatial::Mat3.zero[3, 1]
      end
    end
  end

  describe "#+" do
    it "sums two matrices" do
      a = Chem::Spatial::Mat3[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      b = Chem::Spatial::Mat3[{6, 1, 2}, {25.3, 36, 5}, {0.1, 0.357, 1002.3}]
      c = Chem::Spatial::Mat3[{7, 3, 5}, {29.3, 41, 11}, {7.1, 8.357, 1011.3}]
      (a + b).should eq c
      (a + Chem::Spatial::Mat3.zero).should eq a
    end
  end

  describe "#-" do
    it "negates the matrix" do
      a = Chem::Spatial::Mat3[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      (-a).should eq Chem::Spatial::Mat3[{-1, -2, -3}, {-4, -5, -6}, {-7, -8, -9}]
    end

    it "substracts two matrices" do
      a = Chem::Spatial::Mat3[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      b = Chem::Spatial::Mat3[{6, 1, 2}, {25.3, 36, 5}, {0.1, 0.357, 1002.3}]
      c = Chem::Spatial::Mat3[{-5, 1, 1}, {-21.3, -31, 1}, {6.9, 7.643, -993.3}]
      (a - b).should eq c
      (a - Chem::Spatial::Mat3.zero).should eq a
    end
  end

  describe "#*" do
    it "multiplies by a number" do
      a = Chem::Spatial::Mat3[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      b = Chem::Spatial::Mat3[{2, 4, 6}, {8, 10, 12}, {14, 16, 18}]
      (a * 2).should eq b
      (a * 1).should eq a
    end

    it "multiplies by a triple" do
      expected = Chem::Spatial::Mat3[{2, 4, 6}, {40, 50, 60}, {0.7, 0.8, 0.9}]
      a = Chem::Spatial::Mat3[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      (a * {2, 10, 0.1}).should be_close expected, 1e-15
    end

    it "multiplies by a vector" do
      vec = vec3(7, -9, 2)
      mat = Chem::Spatial::Mat3[
        {2, 4, 9},
        {1, -6, 8},
        {-3, 9, 5},
      ]
      (Chem::Spatial::Mat3.identity * vec).should eq vec
      (mat * vec).should eq [-4, 77, -92]
    end

    it "multiplies two matrices" do
      a = Chem::Spatial::Mat3[{2, 4, 9}, {1, -67, 8}, {9, 78.9, 65}]
      (a * Chem::Spatial::Mat3.identity).should eq a
      (Chem::Spatial::Mat3.identity * a).should eq a

      # taken from chemfiles tests
      a = Chem::Spatial::Mat3[{2, 4, 9}, {1, -6, 8}, {-3, 9, 5}]
      b = Chem::Spatial::Mat3[{7, -1, 0}, {2, 0, 4}, {2, 8, -6}]
      c = Chem::Spatial::Mat3[{40, 70, -38}, {11, 63, -72}, {7, 43, 6}]
      d = Chem::Spatial::Mat3[{13, 34, 55}, {-8, 44, 38}, {30, -94, 52}]
      (a * b).should eq c
      (b * a).should eq d
    end
  end

  describe "#/" do
    it "divides by a number" do
      a = Chem::Spatial::Mat3[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      b = Chem::Spatial::Mat3[{0.5, 1, 1.5}, {2, 2.5, 3}, {3.5, 4, 4.5}]
      (a / 2).should eq b
      (a / 1).should eq a
    end
  end

  describe "#det" do
    it "returns the determinat of the matrix" do
      Chem::Spatial::Mat3[{1, 1, 0}, {4, 9, 2}, {11, 4, 3}].det.should eq 29
      Chem::Spatial::Mat3[{6, 1, 1}, {4, -2, 5}, {2, 8, 7}].det.should eq -306
    end
  end

  describe "#inv" do
    it "returns the inverse of the matrix" do
      mat = Chem::Spatial::Mat3[{1, 1, 0}, {4, 9, 2}, {11, 4, 3}]
      (mat * mat.inv).should be_close Chem::Spatial::Mat3.identity, 1e-15
      (mat.inv * mat).should be_close Chem::Spatial::Mat3.identity, 1e-15
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      expected = "\
        [[ 1 -2 -3 ], \
         [ 4.3e-05  5.23 -66326.3 ], \
         [ 7.1 -80.23  0.09 ]]"
      transform = Chem::Spatial::Mat3[{1, -2, -3}, {4.3e-5, 5.23, -66326.3}, {7.1, -80.23, 9e-2}]
      transform.to_s.should eq expected
    end
  end
end
