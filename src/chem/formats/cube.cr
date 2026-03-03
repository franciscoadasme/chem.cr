@[Chem::RegisterFormat(ext: %w(.cube))]
module Chem::Cube
  # Returns the grid from *io*.
  def self.read(io : IO) : Spatial::Grid
    info = read_info(io)
    struc = read_structure(io) # TODO: skip instead of reading

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

    2.times { pull.consume_line }
    pull.consume_line
    n_atoms = pull.next_i
    pull.error "Cube with multiple densities not supported" if n_atoms < 0
    origin = read_vector(pull).map &.bohrs
    pull.consume_line
    ni, dvi = pull.next_i, read_vector(pull).map &.bohrs
    pull.consume_line
    nj, dvj = pull.next_i, read_vector(pull).map &.bohrs
    pull.consume_line
    nk, dvk = pull.next_i, read_vector(pull).map &.bohrs

    vi, vj, vk = dvi * ni, dvj * nj, dvk * nk
    bounds = Spatial::Parallelepiped.new vi, vj, vk, origin
    info = Spatial::Grid::Info.new bounds, {ni, nj, nk}
  end

  # :ditto:
  def self.read_info(path : Path | String) : Spatial::Grid::Info
    File.open(path) do |file|
      read_info(file)
    end
  end

  # Returns the structure from *io* without reading the data.
  def self.read_structure(io : IO) : Structure
    # we need to jump behind the grid information (third line) to read atom count
    #
    # TODO: try another way as this break pull parser tracking.
    # Note that atom lines starts with an integer and have four columns.
    pos = io.pos
    io.rewind if pos > 0
    2.times { io.gets }
    n_atoms = io.read_line.split[0].to_i
    if pos > 0
      io.pos = pos
    else
      3.times { io.gets }
    end

    pull = PullParser.new(io)
    Structure.build(
      source_file: (file = io).is_a?(File) ? file.path : nil,
    ) do |builder|
      n_atoms.times do
        pull.consume_line
        builder.atom \
          element: (PeriodicTable[pull.next_i]? || pull.error("Unknown element")),
          partial_charge: pull.next_f,
          pos: read_vector(pull)
      end
    end
  end

  # :ditto:
  def self.read_structure(path : Path | String) : Structure
    File.open(path) do |file|
      read_structure(file)
    end
  end

  # Writes a grid to *io*.
  #
  # The structure or group of atoms is written in the header.
  def self.write(io : IO, grid : Spatial::Grid, atoms : AtomView | Structure) : Nil
    atoms = atoms.atoms unless atoms.is_a?(AtomView)

    # write header
    io.puts "CUBE FILE GENERATED WITH CHEM.CR"
    io.puts "OUTER LOOP: X, MIDDLE LOOP: Y, INNER LOOP: Z"
    origin = grid.origin.map &.to_bohrs
    io.printf "%5d%12.6f%12.6f%12.6f\n", atoms.size, origin.x, origin.y, origin.z
    grid.bounds.basisvec.each_with_index do |vec, i|
      vec = vec.map(&.to_bohrs) / grid.dim[i]
      io.printf "%5d%12.6f%12.6f%12.6f\n", grid.dim[i], vec.x, vec.y, vec.z
    end

    # write structure/atoms
    atoms.each do |atom|
      io.printf "%5d%12.6f%12.6f%12.6f%12.6f\n",
        atom.atomic_number,
        atom.partial_charge,
        atom.x.to_bohrs,
        atom.y.to_bohrs,
        atom.z.to_bohrs
    end

    # write grid data
    grid.each_with_index do |ele, i|
      io.printf "%13.5E", ele
      io << '\n' if (i + 1) % 6 == 0
    end
    io << '\n' unless grid.size % 6 == 0
  end

  # :ditto:
  def self.write(path : Path | String, grid : Spatial::Grid, atoms : AtomView | Structure) : Nil
    File.open(path, "w") do |file|
      write(file, grid, atoms)
    end
  end

  private def self.read_vector(pull : PullParser) : Spatial::Vec3
    Spatial::Vec3[pull.next_f, pull.next_f, pull.next_f]
  end
end
