require "../spec_helper"

describe Chem::Spatial::Grid do
  describe ".[]" do
    it "creates an empty grid" do
      grid = Chem::Spatial::Grid[10, 20, 30]
      grid.dim.should eq({10, 20, 30})
      grid.bounds.should eq bounds(0, 0, 0)
      grid.to_a.should eq Array(Float64).new(10*20*30, 0.0)
    end
  end

  describe ".atom_distance" do
    it "returns a grid having distances to nearest atom" do
      st = Chem::Structure.build do
        atom :C, vec3(1, 0, 0)
        atom :C, vec3(0, 0, 1)
      end

      Chem::Spatial::Grid.atom_distance(st, {3, 3, 3}, bounds(2, 2, 2)).to_a.should be_close [
        1.0, 0.0, 1.0,
        1.414, 1.0, 1.414,
        2.236, 2.0, 2.236,

        0.0, 1.0, 1.414,
        1.0, 1.414, 1.732,
        2.0, 2.236, 2.449,

        1.0, 1.414, 2.236,
        1.414, 1.732, 2.449,
        2.236, 2.449, 3.0,
      ], 1e-3
    end

    it "returns a grid having distances to nearest atom" do
      st = Chem::Structure.build do
        cell 2, 2, 2
        atom :C, vec3(1, 1, 1)
        atom :C, vec3(1.5, 0.5, 0.5)
      end

      Chem::Spatial::Grid.atom_distance(st, {4, 4, 4}, bounds(2, 2, 2)).to_a.should be_close [
        0.866, 0.726, 1.093, 0.866, 0.726, 0.553, 0.986, 0.726, 1.093, 0.986, 1.106,
        1.093, 0.866, 0.726, 1.093, 0.866, 1.093, 0.986, 1.106, 1.093, 0.986, 0.577,
        0.577, 0.986, 1.106, 0.577, 0.577, 1.106, 1.093, 0.986, 1.106, 1.093, 0.726,
        0.553, 0.986, 0.726, 0.553, 0.289, 0.577, 0.553, 0.986, 0.577, 0.577, 0.986,
        0.726, 0.553, 0.986, 0.726, 0.866, 0.726, 1.093, 0.866, 0.726, 0.553, 0.986,
        0.726, 1.093, 0.986, 1.106, 1.093, 0.866, 0.726, 1.093, 0.866,
      ], 1e-3
    end
  end

  describe ".atom_distance_like" do
    it "returns a grid with the same bounds and shape of another grid" do
      structure = Chem::Structure.build do
        atom :C, vec3(1, 0, 0)
        atom :C, vec3(0, 0, 1)
      end

      info = Chem::Spatial::Grid::Info.new bounds(1.5, 2.135, 6.12), {10, 10, 10}
      grid = Chem::Spatial::Grid.atom_distance structure, info.dim, info.bounds
      Chem::Spatial::Grid.atom_distance_like(info, structure).should eq grid
    end
  end

  describe ".build" do
    it "builds a grid" do
      grid = Chem::Spatial::Grid.build({2, 3, 2}, bounds(0, 0, 0)) do |buffer|
        12.times do |i|
          buffer[i] = i.to_f ** 2
        end
      end
      grid.to_a.should eq Array(Float64).new(12) { |i| i.to_f ** 2 }
    end
  end

  describe ".empty_like" do
    it "returns a zero-filled grid with the same bounds and shape of another grid" do
      grid = Chem::Spatial::Grid.empty_like make_grid({3, 5, 10}, {1.5, 3, 1.3})
      grid.bounds.should eq bounds(1.5, 3, 1.3)
      grid.dim.should eq({3, 5, 10})
      grid.to_a.minmax.should eq({0, 0})
    end

    it "returns a zero-filled grid with the same bounds and shape of another grid info" do
      grid = Chem::Spatial::Grid.empty_like Chem::Spatial::Grid::Info.new(bounds(2, 2, 4), {20, 20, 20})
      grid.bounds.should eq bounds(2, 2, 4)
      grid.dim.should eq({20, 20, 20})
      grid.to_a.minmax.should eq({0, 0})
    end
  end

  describe ".fill_like" do
    it "returns a filled grid with the same bounds and shape of another grid" do
      grid = Chem::Spatial::Grid.fill_like make_grid({3, 5, 10}, {1.5, 3, 1.3}), 5.0
      grid.bounds.should eq bounds(1.5, 3, 1.3)
      grid.dim.should eq({3, 5, 10})
      grid.to_a.minmax.should eq({5, 5})
    end

    it "returns a filled grid with the same bounds and shape of another grid info" do
      grid = Chem::Spatial::Grid.fill_like Chem::Spatial::Grid::Info.new(bounds(2, 2, 4), {20, 20, 20}), 23.4
      grid.bounds.should eq bounds(2, 2, 4)
      grid.dim.should eq({20, 20, 20})
      grid.to_a.minmax.should eq({23.4, 23.4})
    end
  end

  describe ".new" do
    it "initializes a grid" do
      grid = Chem::Spatial::Grid.new({2, 3, 2}, bounds(1, 1, 1))
      grid.dim.should eq({2, 3, 2})
      grid.ni.should eq 2
      grid.nj.should eq 3
      grid.nk.should eq 2
      grid.resolution.should eq({1, 0.5, 1})
      grid.to_a.should eq Array(Float64).new(12, 0.0)
    end

    it "initializes a grid with an initial value" do
      grid = Chem::Spatial::Grid.new({2, 3, 2}, bounds(0, 0, 0), initial_value: 3.14)
      grid.to_a.should eq Array(Float64).new 12, 3.14
    end

    it "initializes a grid with a block" do
      grid = Chem::Spatial::Grid.new({2, 3, 2}, bounds(0, 0, 0)) { |i, j, k| i * 100 + j * 10 + k }
      grid.to_a.should eq [0, 1, 10, 11, 20, 21, 100, 101, 110, 111, 120, 121]
    end
  end

  describe ".vdw_mask" do
    it "returns a vdW mask" do
      st = Chem::Structure.build do
        atom :C, vec3(1, 0, 0)
        atom :C, vec3(0, 0, 1)
      end

      actual = [] of Chem::Spatial::Vec3
      Chem::Spatial::Grid.vdw_mask(st, {6, 6, 6}, bounds(2, 2, 2), 0.02).each_with_coords do |ele, vec|
        actual << vec if ele == 1
      end
      actual.should be_close [
        vec3(0.4, 1.6, 0.4),
        vec3(0.4, 1.6, 1.6),
        vec3(0.8, 1.2, 2.0),
        vec3(1.2, 0.8, 2.0),
        vec3(1.6, 0.4, 1.6),
        vec3(1.6, 1.6, 0.4),
        vec3(2.0, 0.8, 1.2),
        vec3(2.0, 1.2, 0.8),
      ], 1e-3
    end
  end

  describe ".vdw_mask_like" do
    it "returns a grid with the same bounds and shape of another grid" do
      structure = Chem::Structure.build do
        atom :C, vec3(1, 0, 0)
        atom :C, vec3(0, 0, 1)
      end

      info = Chem::Spatial::Grid::Info.new bounds(1.5, 2.135, 6.12), {10, 10, 10}
      grid = Chem::Spatial::Grid.vdw_mask structure, info.dim, info.bounds
      Chem::Spatial::Grid.vdw_mask_like(info, structure).should eq grid
    end
  end

  describe "#==" do
    it "returns true when grids are equal" do
      grid = make_grid({3, 5, 4}, Chem::Spatial::Parallelepiped.new(vec3(0, 1, 3), vec3(30, 20, 25)))
      other = make_grid({3, 5, 4}, Chem::Spatial::Parallelepiped.new(vec3(0, 1, 3), vec3(30, 20, 25)))
      grid.should eq other
    end

    it "returns false when grids have different number of points" do
      Chem::Spatial::Grid[5, 7, 10].should_not eq Chem::Spatial::Grid[5, 7, 9]
    end

    it "returns false when grids have different bounds" do
      grid = make_grid({5, 5, 5}, Chem::Spatial::Parallelepiped.new(vec3(0, 1, 3), vec3(30, 20, 25)))
      other = make_grid({5, 5, 5}, {0, 0, 0})
      grid.should_not eq other
    end

    it "returns false when grids have different elements" do
      make_grid({5, 5, 5}).should_not eq make_grid({5, 5, 5}) { |i| i + 1 }
    end
  end

  describe "#+" do
    it "sums a grid with a number" do
      (make_grid({2, 2, 2}) + 10).to_a.should eq [10, 11, 12, 13, 14, 15, 16, 17]
    end

    it "sums two grids" do
      (make_grid({2, 2, 2}) + make_grid({2, 2, 2})).to_a.should eq [0, 2, 4, 6, 8, 10, 12, 14]
    end

    it "fails when grids have different shape" do
      expect_raises ArgumentError do
        Chem::Spatial::Grid[2, 2, 2] + Chem::Spatial::Grid[3, 2, 2]
      end
    end
  end

  describe "#[]" do
    it "fails when index is out of bounds" do
      expect_raises(IndexError) { make_grid({2, 3, 2})[192] }
    end

    it "fails when location is out of bounds" do
      expect_raises(IndexError) { make_grid({2, 3, 2})[2, 24, 0] }
      expect_raises(IndexError) { make_grid({2, 3, 2})[{1, 67, 198}] }
    end

    it "fails when coordinates are out of bounds" do
      grid = make_grid({10, 10, 10}, {2, 3, 4})
      expect_raises(IndexError) { grid[vec3(2, 5, -0.5)] }
    end
  end

  describe "#[]?" do
    it "returns the value at the index" do
      grid = make_grid({2, 3, 2})
      grid[0]?.should eq 0
      grid[5]?.should eq 5
      grid[11]?.should eq 11
      grid[-1]?.should eq 11
    end

    it "returns the value at the location" do
      grid = make_grid({2, 3, 2})
      grid[0, 0, 0]?.should eq 0
      grid[0, 1, 1]?.should eq 3
      grid[{1, 2, 0}]?.should eq 10
      grid[{1, 2, 1}]?.should eq 11
      grid[0, -3, -2]?.should eq 0
      grid[{-1, -1, -1}]?.should eq 11
    end

    it "returns the value at the coordinates" do
      grid = make_grid({6, 11, 9}, bounds(1, 1, 1).translate(vec3(2, 3, 4)))
      grid[vec3(2, 3, 4)]?.should eq 0
      grid[vec3(2.2, 3.6, 4.25)]?.should eq 155
      grid[vec3(3, 4, 5)]?.should eq 593
    end

    it "returns the value close to the coordinates" do
      grid = make_grid({6, 10, 8}, bounds(1, 1, 1).translate(vec3(2, 3, 4)))
      grid[vec3(2.51, 3.505, 4.51)]?.should eq 284 # no interpolation
      grid[vec3(2.65, 3.24, 4.97)]?.should eq 263  # no interpolation
    end

    it "returns nil when index is out of bounds" do
      make_grid({2, 3, 2})[100]?.should be_nil
    end

    it "returns nil when location is out of bounds" do
      grid = make_grid({2, 3, 2})
      grid[3, 5, 10]?.should be_nil
      grid[-10, 1, 1]?.should be_nil
    end

    it "returns nil when coordinates are out of bounds" do
      grid = make_grid({10, 10, 10}, {2, 3, 4})
      grid[vec3(2, 5, -0.5)]?.should be_nil
    end
  end

  describe "#[]=" do
    it "sets a value at the index" do
      grid = make_grid({2, 3, 2})
      grid[4] = 1234
      grid[-1] = 999
      grid.to_a.should eq [0, 1, 2, 3, 1234, 5, 6, 7, 8, 9, 10, 999]
    end

    it "sets a value at the location" do
      grid = make_grid({10, 10, 10})
      grid[4, 7, 1] = 1234
      grid[4, 7, 1].should eq 1234
      grid[{6, 5, 9}] = -9999
      grid[{6, 5, 9}].should eq -9999
    end
  end

  describe "#coords_at" do
    it "fails when index is out of bounds" do
      expect_raises(IndexError) { make_grid({2, 3, 4}).coords_at 285 }
    end

    it "fails when location is out of bounds" do
      grid = make_grid({10, 10, 10}, bounds(10, 20, 30).translate(vec3(1, 2, 3)))
      expect_raises(IndexError) { grid.coords_at 20, 35, 1 }
    end
  end

  describe "#coords_at?" do
    it "returns the coordinates at index" do
      grid = make_grid({11, 11, 11}, bounds(10, 10, 10).translate(vec3(8, 5, 4)))
      grid.coords_at?(0).should eq [8, 5, 4]
      grid.coords_at?(1330).should eq [18, 15, 14]
      grid.coords_at?(-1).should eq [18, 15, 14]
      grid.coords_at?(75).should eq [8, 11, 13]
    end

    it "returns the coordinates at location" do
      grid = make_grid({11, 11, 11}, bounds(10, 20, 30).translate(vec3(1, 2, 3)))
      grid.coords_at?(0, 0, 0).should eq [1, 2, 3]
      grid.coords_at?(10, 10, 10).should eq [11, 22, 33]
      grid.coords_at?(3, 5, 0).should eq [4, 12, 3]
    end

    it "returns the coordinates at location (non-orthogonal)" do
      bounds = Chem::Spatial::Parallelepiped.hexagonal(10, 5).translate(vec3(1, 2, 3))
      grid = make_grid({11, 11, 11}, bounds)
      grid.coords_at?(0, 0, 0).should eq [1, 2, 3]
      grid.coords_at?(10, 10, 10).not_nil!.should be_close [6, 10.660, 8], 1e-3
      grid.coords_at?(3, 5, 0).not_nil!.should be_close [1.5, 6.330, 3], 1e-3
    end

    it "returns nil when index is out of bounds" do
      make_grid({2, 2, 2}).coords_at?(356).should be_nil
    end

    it "returns nil when location is out of bounds" do
      grid = make_grid({10, 10, 10}, bounds(10, 20, 30).translate(vec3(1, 2, 3)))
      grid.coords_at?(20, 35, 1).should be_nil
    end
  end

  describe "#dup" do
    it "returns a copy" do
      grid = make_grid({3, 5, 4}, Chem::Spatial::Parallelepiped.new(vec3(0, 1, 3), vec3(30, 20, 25)))
      other = grid.dup
      other.should_not be grid
      other.should eq grid
    end
  end

  describe "#each" do
    it "yields each element" do
      ary = [] of Float64
      make_grid({2, 3, 1}) { |i, j, k| i * 100 + j * 10 + k }.each { |ele| ary << ele }
      ary.should eq [0, 10, 20, 100, 110, 120]
    end

    it "returns an iterator" do
      grid = make_grid({2, 3, 2}) { |i, j, k| i * 6 + j * 2 + k }
      grid.each.to_a.should eq (0..11).to_a
    end
  end

  describe "#each_coords" do
    it "yields each coordinates" do
      ary = [] of Chem::Spatial::Vec3
      Chem::Spatial::Grid.new({2, 2, 2}, bounds(3, 3, 3).translate(vec3(1, 2, 3))).each_coords do |vec|
        ary << vec
      end

      ary.should eq [
        vec3(1, 2, 3), vec3(1, 2, 6), vec3(1, 5, 3), vec3(1, 5, 6), vec3(4, 2, 3), vec3(4, 2, 6),
        vec3(4, 5, 3), vec3(4, 5, 6),
      ]
    end
  end

  describe "#each_loc" do
    it "yields each loc" do
      ary = [] of Chem::Spatial::Grid::Location
      make_grid({2, 2, 2}).each_loc { |i, j, k| ary << {i, j, k} }
      ary.should eq [
        {0, 0, 0}, {0, 0, 1}, {0, 1, 0}, {0, 1, 1}, {1, 0, 0}, {1, 0, 1}, {1, 1, 0},
        {1, 1, 1},
      ]
    end

    it "yields each loc within a cutoff distance of a given position" do
      grid = Chem::Spatial::Grid.new({5, 10, 20}, bounds(2, 2, 2).translate(vec3(1, 2, 3)))
      vec, cutoff = vec3(2, 3, 5), 0.5

      expected = [] of Chem::Spatial::Grid::Location
      grid.each_loc do |i, j, k|
        d = Chem::Spatial.distance2 grid.coords_at(i, j, k), vec
        expected << {i, j, k} if d < cutoff**2
      end

      ary = [] of Chem::Spatial::Grid::Location
      grid.each_loc(vec, cutoff) { |(i, j, k)| ary << {i, j, k} }
      ary.sort!.should eq expected.sort!
    end
  end

  describe "#each_axial_slice" do
    it "yields each yz slice" do
      ary = [] of Array(Float64)
      make_grid({2, 3, 2}).each_axial_slice(0) { |slice| ary << slice }
      ary.should eq [(0..5).to_a, (6..11).to_a]
    end

    it "yields each xz slice" do
      ary = [] of Array(Float64)
      make_grid({2, 3, 2}).each_axial_slice(1) { |slice| ary << slice }
      ary.should eq [[0, 1, 6, 7], [2, 3, 8, 9], [4, 5, 10, 11]]
    end

    it "yields each xy slice" do
      ary = [] of Array(Float64)
      make_grid({2, 3, 2}).each_axial_slice(2) { |slice| ary << slice }
      ary.should eq [[0, 2, 4, 6, 8, 10], [1, 3, 5, 7, 9, 11]]
    end

    it "reuses an array" do
      ary = [] of Array(Float64)
      buffer = [] of Float64
      make_grid({2, 3, 2}).each_axial_slice(2, buffer) do |slice|
        slice.should be buffer
        ary << slice.dup
      end
      ary.should eq [[0, 2, 4, 6, 8, 10], [1, 3, 5, 7, 9, 11]]
    end

    it "creates and reuses an array" do
      ary = [] of Array(Float64)
      buffer = nil
      make_grid({2, 3, 2}).each_axial_slice(2, reuse: true) do |slice|
        buffer ||= slice
        slice.should be buffer
        ary << slice.dup
      end
      ary.should eq [[0, 2, 4, 6, 8, 10], [1, 3, 5, 7, 9, 11]]
    end

    it "fails when axis is out of bounds" do
      expect_raises(IndexError) do
        make_grid({2, 2, 2}).each_axial_slice(5) { }
      end
    end
  end

  describe "#each_with_coords" do
    it "yields each element with its coordinates" do
      hash = {} of Chem::Spatial::Vec3 => Float64
      grid = make_grid({3, 2, 1}, bounds(2, 1, 1).translate(vec3(1, 2, 3))) do |i, j, k|
        i * 100 + j * 10 + k
      end
      grid.each_with_coords { |ele, vec| hash[vec] = ele }
      hash.should eq({
        vec3(1, 2, 3) => 0,
        vec3(1, 3, 3) => 10,
        vec3(2, 2, 3) => 100,
        vec3(2, 3, 3) => 110,
        vec3(3, 2, 3) => 200,
        vec3(3, 3, 3) => 210,
      })
    end
  end

  describe "#index" do
    it "returns the index at the location" do
      grid = make_grid({2, 3, 2})
      grid.index({0, 1, 1}).should eq 3
    end

    it "returns the index at the coordinates" do
      grid = make_grid({11, 11, 11}, bounds(10, 10, 10).translate(vec3(8, 1, 5)))
      grid.index(vec3(13, 7, 12)).should eq 678
    end
  end

  describe "#index!" do
    it "fails when location is out of bounds" do
      expect_raises(IndexError) { make_grid({2, 3, 2}).index!({10, 10, 10}) }
    end

    it "fails when vector is out of bounds" do
      expect_raises(IndexError) do
        make_grid({2, 3, 2}, bounds(10, 10, 10)).index! vec3(26, 23, 0.1)
      end
    end
  end

  describe "#loc_at" do
    it "fails when index is out of bounds" do
      expect_raises(IndexError) { make_grid({8, 8, 8}).loc_at 1267 }
    end

    it "fails when coordinates are out of bounds" do
      grid = make_grid({8, 8, 8}, bounds(7, 1, 2))
      expect_raises(IndexError) { grid.loc_at vec3(7.1, 0.5, 1.2) }
    end
  end

  describe "#loc_at?" do
    it "returns the location at the index" do
      grid = make_grid({2, 3, 2})
      grid.loc_at?(0).should eq({0, 0, 0})
      grid.loc_at?(5).should eq({0, 2, 1})
      grid.loc_at?(11).should eq({1, 2, 1})
    end

    it "returns the location at the coordinates" do
      grid = make_grid({6, 10, 8}, bounds(1, 1, 1).translate(vec3(2, 3, 4)))
      grid.loc_at?(vec3(2, 3, 4)).should eq({0, 0, 0})
      grid.loc_at?(vec3(3, 4, 5)).should eq({5, 9, 7})
      grid.loc_at?(vec3(2.45, 3.4, 4.4)).should eq({2, 4, 3})
      grid.loc_at?(vec3(2.16, 3.75, 4.87)).should eq({1, 7, 6})
    end

    it "returns the location at the coordinates (non-orthogonal)" do
      bounds = Chem::Spatial::Parallelepiped.new(vec3(4, 3, 2), {5, 5, 4}, {90, 100, 90})
      grid = make_grid({11, 11, 11}, bounds)
      grid.loc_at?(vec3(4, 3, 2)).should eq({0, 0, 0})
      grid.loc_at?(vec3(8.305, 8, 5.939)).should eq({10, 10, 10})
      grid.loc_at?(vec3(4.5, 6.21, 2.63)).should eq({1, 6, 2})
      grid.loc_at?(vec3(7.4, 4.91, 5.4)).should eq({8, 4, 9})
    end

    it "returns nil when index is out of bounds" do
      make_grid({2, 3, 2}).loc_at?(120).should be_nil
    end

    it "returns nil when coordinates are out of bounds" do
      make_grid({8, 8, 8}, bounds(7, 1, 2)).loc_at?(vec3(7.1, 0.5, 1.2)).should be_nil
    end
  end

  describe "#map" do
    it "returns a grid yielding each element" do
      grid = make_grid({2, 3, 1})
      other = grid.map &.**(2)
      grid.to_a.should eq [0, 1, 2, 3, 4, 5]
      other.to_a.should eq [0, 1, 4, 9, 16, 25]
      other.bounds.should eq bounds(0, 0, 0)
    end
  end

  describe "#map!" do
    it "modifies a grid yielding each element" do
      grid = make_grid({2, 3, 1})
      grid.map! &.**(2)
      grid.to_a.should eq [0, 1, 4, 9, 16, 25]
    end
  end

  describe "#map_with_coords" do
    it "modifies the grid yielding each element and its coordinates" do
      grid = make_grid({3, 2, 1}, bounds(2, 1, 1).translate(vec3(1, 2, 3)))
      other = grid.map_with_coords { |ele, vec| ele + vec.x * 100 + vec.y * 10 + vec.z }
      grid.to_a.should eq [0, 1, 2, 3, 4, 5]
      other.to_a.should eq [123, 134, 225, 236, 327, 338]
      other.bounds.should eq bounds(2, 1, 1).translate(vec3(1, 2, 3))
    end
  end

  describe "#map_with_coords!" do
    it "modifies the grid yielding each element and its coordinates" do
      grid = make_grid({3, 2, 1}, bounds(2, 1, 1).translate(vec3(1, 2, 3)))
      grid.map_with_coords! { |ele, vec| ele + vec.x * 100 + vec.y * 10 + vec.z }
      grid.to_a.should eq [123, 134, 225, 236, 327, 338]
    end
  end

  describe "#map_with_index" do
    it "returns a grid mapped by yielding each element and its index" do
      grid = make_grid({2, 3, 1})
      other = grid.map_with_index { |ele, i| ele * i }
      grid.to_a.should eq [0, 1, 2, 3, 4, 5]
      other.to_a.should eq [0, 1, 4, 9, 16, 25]
      other.dim.should eq({2, 3, 1})
      other.bounds.should eq bounds(0, 0, 0)
    end
  end

  describe "#map_with_index!" do
    it "maps in-place by yielding each element and its index" do
      grid = make_grid({2, 3, 1})
      grid.map_with_index! { |ele, i| ele * i }
      grid.to_a.should eq [0, 1, 4, 9, 16, 25]
    end
  end

  describe "#map_with_loc" do
    it "returns a grid mapped by yielding each element and its location" do
      grid = make_grid({2, 3, 1})
      other = grid.map_with_loc { |ele, (i, j, k)| i * 1000 + j * 100 + k * 10 + ele }
      grid.to_a.should eq [0, 1, 2, 3, 4, 5]
      other.to_a.should eq [0, 101, 202, 1003, 1104, 1205]
      other.bounds.should eq bounds(0, 0, 0)
    end
  end

  describe "#map_with_loc!" do
    it "maps in-place by yielding each element and its location" do
      grid = make_grid({2, 3, 1})
      grid.map_with_loc! { |ele, (i, j, k)| i * 1000 + j * 100 + k * 10 + ele }
      grid.to_a.should eq [0, 101, 202, 1003, 1104, 1205]
    end
  end

  describe "#mask" do
    it "returns a masked grid by a number" do
      grid = make_grid({2, 2, 2}) { |i, j, k| i + j + k }
      grid.mask(2).to_a.should eq [0, 0, 0, 1, 0, 1, 1, 0]
      grid.to_a.should eq [0, 1, 1, 2, 1, 2, 2, 3]
    end

    it "returns a masked grid by a number+-delta" do
      grid = make_grid({2, 2, 3}) { |i, j, k| (i + 1) * (j + 1) * (k + 1) / 5 }
      grid.mask(1, 0.5).to_a.should eq [0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 0]
      grid.to_a.should eq [0.2, 0.4, 0.6, 0.4, 0.8, 1.2, 0.4, 0.8, 1.2, 0.8, 1.6, 2.4]
    end

    it "returns a masked grid by a range" do
      grid = make_grid({2, 2, 3}) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
      grid.mask(2..4.5).to_a.should eq [0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0]
      grid.to_a.should eq [1, 2, 3, 2, 4, 6, 2, 4, 6, 4, 8, 12]
    end

    it "returns a masked grid with a block" do
      grid = make_grid({2, 2, 3}) { |i, j, k| (i + 1) / (j + 1) * (k + 1) }
      grid.mask(&.<(2)).to_a.should eq [1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0]
      grid.to_a.should eq [1, 2, 3, 0.5, 1, 1.5, 2, 4, 6, 1, 2, 3]
    end
  end

  describe "#mask!" do
    it "masks a grid in-place by a number" do
      grid = make_grid({2, 3, 2}) { |i, j, k| i + j + k }
      grid.mask! 3
      grid.to_a.should eq [0, 0, 0, 0, 0, 3, 0, 0, 0, 3, 3, 0]
    end

    it "masks a grid in-place by a number+-delta" do
      grid = make_grid({2, 2, 3}) { |i, j, k| (i + j + k) / 5 }
      grid.mask! 0.5, 0.1
      grid.to_a.should eq [0, 0, 0.4, 0, 0.4, 0.6, 0, 0.4, 0.6, 0.4, 0.6, 0]
    end

    it "masks a grid in-place by a range" do
      grid = make_grid({2, 3, 2}) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
      grid.mask! 3..10
      grid.to_a.should eq [0, 0, 0, 4, 3, 6, 0, 4, 4, 8, 6, 0]
    end

    it "masks a grid in-place with a block" do
      grid = make_grid({2, 3, 2}) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
      grid.mask! &.>(4.1)
      grid.to_a.should eq [0, 0, 0, 0, 0, 6, 0, 0, 0, 8, 6, 12]
    end
  end

  describe "#mask_by_coords" do
    it "returns a grid mask" do
      grid = make_grid({2, 2, 2}, bounds(1, 1, 1))
      grid.mask_by_coords(&.x.==(0)).to_a.should eq [1, 1, 1, 1, 0, 0, 0, 0]
      grid.to_a.should eq [0, 1, 2, 3, 4, 5, 6, 7]
    end
  end

  describe "#mask_by_coords!" do
    it "masks a grid in-place by coordinates" do
      grid = make_grid({2, 2, 2}, bounds(5, 5, 5))
      grid.mask_by_coords! { |vec| vec.y == 5 }
      grid.to_a.should eq [0, 0, 2, 3, 0, 0, 6, 7]
    end
  end

  describe "#mask_by_index" do
    it "returns a grid mask" do
      grid = make_grid({2, 2, 2})
      grid.mask_by_index { |i| i < 4 }.to_a.should eq [1, 1, 1, 1, 0, 0, 0, 0]
      grid.to_a.should eq [0, 1, 2, 3, 4, 5, 6, 7]
    end
  end

  describe "#mask_by_index!" do
    it "masks a grid in-place by index" do
      grid = make_grid({2, 2, 2})
      grid.mask_by_index! { |i| 1 <= i < 6 }
      grid.to_a.should eq [0, 1, 2, 3, 4, 5, 0, 0]
    end
  end

  describe "#mask_by_loc" do
    it "returns a grid mask" do
      grid = make_grid({2, 2, 2})
      grid.mask_by_loc { |(i, j, k)| k == 1 }.to_a.should eq [0, 1, 0, 1, 0, 1, 0, 1]
      grid.to_a.should eq [0, 1, 2, 3, 4, 5, 6, 7]
    end
  end

  describe "#mask_by_loc!" do
    it "masks a grid in-place by location" do
      grid = make_grid({2, 2, 2})
      grid.mask_by_loc! { |(i, j, k)| i == 1 }
      grid.to_a.should eq [0, 0, 0, 0, 4, 5, 6, 7]
    end
  end

  describe "#mean" do
    it "returns the arithmetic mean" do
      make_grid({2, 3, 4}).mean.should eq 11.5
    end

    it "returns the arithmetic mean along an axis" do
      make_grid({2, 3, 4}).mean(axis: 0).should eq [5.5, 17.5]
      make_grid({2, 3, 4}).mean(axis: 1).should eq [7.5, 11.5, 15.5]
      make_grid({2, 3, 4}).mean(axis: 2).should eq [10, 11, 12, 13]
    end

    it "fails when axis is out of bounds" do
      expect_raises(IndexError) { make_grid({2, 2, 2}).mean(axis: 4) }
    end
  end

  describe "#mean_with_coords" do
    it "returns the arithmetic mean along an axis with its coordinates" do
      ary = make_grid({2, 3, 11}, bounds(4, 5, 6)).mean_with_coords(axis: 2)
      ary.map(&.[0]).should eq [
        27.5, 28.5, 29.5, 30.5, 31.5, 32.5, 33.5, 34.5, 35.5, 36.5, 37.5,
      ]
      ary.map(&.[1]).should be_close [
        0, 0.6, 1.2, 1.8, 2.4, 3, 3.6, 4.2, 4.8, 5.4, 6,
      ], 1e-15
    end
  end

  describe "#min" do
    it "returns the minimum value" do
      ((make_grid({2, 3, 2}) - 5) * 25).min.should eq -125
    end
  end

  describe "#ni" do
    it "returns the number of points along the first axis" do
      make_grid({2, 6, 1}).ni.should eq 2
    end
  end

  describe "#nj" do
    it "returns the number of points along the second axis" do
      make_grid({2, 6, 1}).nj.should eq 6
    end
  end

  describe "#nk" do
    it "returns the number of points along the third axis" do
      make_grid({2, 6, 1}).nk.should eq 1
    end
  end

  describe "#resolution" do
    it "returns the spacing for each axis" do
      make_grid({10, 10, 10}, bounds(1, 2, 3)).resolution.should eq({1/9, 2/9, 3/9})
    end
  end

  describe "#size" do
    it "returns the number of points" do
      make_grid({2, 5, 10}).size.should eq 100
    end
  end

  describe "#step" do
    it "returns a smaller grid" do
      grid = make_grid({4, 4, 4}, bounds(1, 1, 1)).step 2, 3, 2
      grid.dim.should eq({2, 2, 2})
      grid.resolution.should eq({1, 1, 1})
      grid.to_a.should eq [0, 2, 12, 14, 32, 34, 44, 46]
    end
  end

  describe "#sum" do
    it "returns the sum of all values" do
      make_grid({2, 3, 2}).sum.should eq (0..11).sum
    end
  end

  describe "#to_a" do
    it "returns an array containing all elements" do
      make_grid({2, 2, 2}).to_a.should eq (0..7).to_a
    end
  end
end
