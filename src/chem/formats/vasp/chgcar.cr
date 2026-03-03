@[Chem::RegisterFormat(names: %w(CHGCAR*))]
module Chem::VASP::Chgcar
  # Returns the charge density from *io*.
  def self.read(io : IO) : Spatial::Grid
    info = read_info(io)

    pull = PullParser.new(io)
    inv_volume = 1.0 / info.bounds.volume
    nx, ny, nz = info.dim
    nyz = ny * nz
    source_file = (file = io).is_a?(File) ? file.path : nil
    Spatial::Grid.build(info, source_file) do |buffer|
      nz.times do |k|
        ny.times do |j|
          nx.times do |i|
            !pull.consume_token.eol? || pull.consume_line.consume_token
            buffer[i * nyz + j * nz + k] = pull.float * inv_volume
          end
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
    struc = read_structure(io) # TODO: skip, do not parse the structure
    pull = PullParser.new(io)
    pull.consume_line
    nx, ny, nz = pull.next_i, pull.next_i, pull.next_i
    raise "BUG: unit cell cannot be nil" unless cell = struc.cell?
    Spatial::Grid::Info.new cell, {nx, ny, nz}
  end

  # :ditto:
  def self.read_info(path : Path | String) : Spatial::Grid::Info
    File.open(path) do |file|
      read_info(file)
    end
  end

  # Returns the structure from *io* without reading the data.
  # Equivalent to `Poscar.read`.
  def self.read_structure(io : IO) : Structure
    Poscar.read(io)
  end

  # :ditto:
  def self.read_structure(path : Path | String) : Structure
    File.open(path) do |file|
      read_structure(file)
    end
  end

  # Writes a grid to *io*.
  #
  # The structure is written in the header.
  # Raises `ArgumentError` if the structure's unit cell does not match the grid bounds.
  def self.write(io : IO, grid : Spatial::Grid, struc : Structure) : Nil
    raise ArgumentError.new("Incompatible structure and grid") unless struc.cell.size == grid.bounds.size

    Poscar.write(io, struc)

    io.puts
    nx, ny, nz = grid.dim
    io.printf "%5d%5d%5d\n", nx, ny, nz
    grid.size.times do |i_|
      i = i_ % grid.ni
      j = (i_ // grid.ni) % grid.nj
      k = i_ // (grid.ni * grid.nj)
      write(io, grid.unsafe_fetch({i, j, k}) * grid.volume)
      io << '\n' if (i_ + 1) % 5 == 0
    end
    io << '\n' unless grid.size % 5 == 0
  end

  # :ditto:
  def self.write(path : Path | String, grid : Spatial::Grid, structure : Structure) : Nil
    File.open(path, "w") do |file|
      write(file, grid, structure)
    end
  end

  private def self.write(io : IO, value : Float64) : Nil
    if value == 0
      io.printf "%18.11E", value
    else
      s = sprintf "%.10E", value
      if value > 0
        exp = s[13..].to_i + 1
        io << " 0." << s[0] << s[2..11]
      else
        exp = s[14..].to_i + 1
        io << " -." << s[1] << s[3..12]
      end
      io << 'E'
      io << (exp < 0 ? '-' : '+')
      io.printf "%02d", exp.abs
    end
  end
end
