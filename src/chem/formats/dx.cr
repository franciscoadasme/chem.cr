@[Chem::RegisterFormat(ext: %w(.dx))]
module Chem::DX
  # Returns the grid from *io*.
  def self.read(io : IO) : Spatial::Grid
    info = read_info io
    pull = PullParser.new(io)
    Spatial::Grid.build(
      info,
      source_file: (file = io).is_a?(File) ? file.path : nil,
    ) do |buffer, size|
      i = 0
      pull.each_line do
        while i < size && !pull.consume_token.eol?
          buffer[i] = pull.float
          i += 1
        end
      end
    end
  end

  # :ditto:
  def self.read(path : Path | String) : Spatial::Grid
    File.open(path) do |file|
      read(file)
    end
  end

  # Returns the grid information from *io* without reading the data.
  def self.read_info(io : IO) : Spatial::Grid::Info
    pull = PullParser.new(io)
    pull.each_line do
      break unless pull.consume_token.char == '#'
    end

    4.times { pull.consume_token }
    ni, nj, nk = pull.next_i, pull.next_i, pull.next_i
    pull.consume_line
    pull.consume_token # skip origin word
    origin = Spatial::Vec3[pull.next_f, pull.next_f, pull.next_f]
    pull.consume_line
    vi, vj, vk = {ni, nj, nk}.map do |n|
      pull.consume_token # skip delta word
      delta = Spatial::Vec3[pull.next_f, pull.next_f, pull.next_f]
      pull.consume_line
      delta * (n - 1)
    end
    pull.consume_line

    bounds = Spatial::Parallelepiped.new vi, vj, vk, origin
    Spatial::Grid::Info.new bounds, {ni, nj, nk}
  end

  # :ditto:
  def self.read_info(path : Path | String) : Spatial::Grid::Info
    File.open(path) do |file|
      read_info(file)
    end
  end

  # Writes a grid to *io*.
  def self.write(io : IO, grid : Spatial::Grid) : Nil
    rx, ry, rz = grid.resolution
    io.printf "object 1 class gridpositions counts %d %d %d\n", grid.ni, grid.nj, grid.nk
    io.printf "origin%8.3f%8.3f%8.3f\n", grid.origin.x, grid.origin.y, grid.origin.z
    io.printf "delta %8.3f%8.3f%8.3f\n", rx, 0, 0
    io.printf "delta %8.3f%8.3f%8.3f\n", 0, ry, 0
    io.printf "delta %8.3f%8.3f%8.3f\n", 0, 0, rz
    io.printf "object 2 class gridconnections counts %d %d %d\n", grid.ni, grid.nj, grid.nk
    io.printf "object 3 class array type double rank 0 items %d data follows\n", grid.size
    grid.each_with_index do |ele, i|
      io.printf "%16.8f", ele
      io << '\n' if (i + 1) % 3 == 0
    end
    io << '\n' unless grid.size % 3 == 0
  end

  # :ditto:
  def self.write(path : Path | String, grid : Spatial::Grid) : Nil
    File.open(path, "w") do |file|
      write(file, grid)
    end
  end
end
