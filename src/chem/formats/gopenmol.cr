# gOpenMol binary plot (*.plt) grids.
#
# Header is five 32-bit integers (rank, surface type, nz, ny, nx) followed by
# six 32-bit floats (zmin, zmax, ymin, ymax, xmin, xmax) in bohrs. Rank must be
# 3. Data are 32-bit floats with X fastest, then Y, then Z. Endianness is
# detected from the rank field. FORTRAN unformatted files are not supported.
#
# Format description: http://web.archive.org/web/20061011125817/http://www.csc.fi/gopenmol/developers/plt_format.phtml
@[Chem::RegisterFormat(ext: %w(.plt))]
module Chem::GOpenMol
  # Returns the grid from *io*.
  def self.read(io : IO) : Spatial::Grid
    byte_format = detect_byte_format(io)
    info = decode_header(io, byte_format)

    nx, ny, nz = info.dim
    nyz = ny * nz
    Spatial::Grid.build(
      info,
      source_file: (file = io).is_a?(File) ? file.path : nil,
    ) do |buffer|
      nz.times do |k|
        ny.times do |j|
          nx.times do |i|
            buffer[i * nyz + j * nz + k] = io.read_bytes(Float32, byte_format).to_f
          end
        end
      end
    end
  end

  # Returns the grid information from *io* without reading the data.
  def self.read_info(io : IO) : Spatial::Grid::Info
    decode_header(io, detect_byte_format(io))
  end

  define_file_overload(GOpenMol, read, read_info)

  # Writes a grid to *io* as a little-endian gOpenMol binary plot.
  #
  # Coordinates are written in bohrs. Only orthogonal grids are supported.
  def self.write(io : IO, grid : Spatial::Grid) : Nil
    unless grid.bounds.orthogonal?
      raise ArgumentError.new("gOpenMol format only supports orthogonal grids")
    end

    byte_format = IO::ByteFormat::LittleEndian
    origin = grid.origin
    size = grid.bounds.size
    nx, ny, nz = grid.dim

    io.write_bytes 3, byte_format # rank
    io.write_bytes 2, byte_format # orbital/density surface
    io.write_bytes nz, byte_format
    io.write_bytes ny, byte_format
    io.write_bytes nx, byte_format
    io.write_bytes origin.z.to_bohrs.to_f32, byte_format
    io.write_bytes (origin.z + size.z).to_bohrs.to_f32, byte_format
    io.write_bytes origin.y.to_bohrs.to_f32, byte_format
    io.write_bytes (origin.y + size.y).to_bohrs.to_f32, byte_format
    io.write_bytes origin.x.to_bohrs.to_f32, byte_format
    io.write_bytes (origin.x + size.x).to_bohrs.to_f32, byte_format

    nz.times do |k|
      ny.times do |j|
        nx.times do |i|
          io.write_bytes grid.unsafe_fetch({i, j, k}).to_f32, byte_format
        end
      end
    end
  end

  define_file_overload(GOpenMol, write, mode: "w")

  private def self.decode_header(io : IO, byte_format : IO::ByteFormat) : Spatial::Grid::Info
    io.read_bytes(Int32, byte_format) # surface type
    nz = io.read_bytes(Int32, byte_format)
    ny = io.read_bytes(Int32, byte_format)
    nx = io.read_bytes(Int32, byte_format)
    zmin = io.read_bytes(Float32, byte_format).to_f.bohrs
    zmax = io.read_bytes(Float32, byte_format).to_f.bohrs
    ymin = io.read_bytes(Float32, byte_format).to_f.bohrs
    ymax = io.read_bytes(Float32, byte_format).to_f.bohrs
    xmin = io.read_bytes(Float32, byte_format).to_f.bohrs
    xmax = io.read_bytes(Float32, byte_format).to_f.bohrs

    bounds = Spatial::Parallelepiped.new(
      Spatial::Vec3[xmin, ymin, zmin],
      Spatial::Vec3[xmax, ymax, zmax],
    )
    Spatial::Grid::Info.new bounds, {nx, ny, nz}
  end

  private def self.detect_byte_format(io : IO) : IO::ByteFormat
    bytes = Bytes.new(sizeof(Int32))
    io.read_fully(bytes)
    return IO::ByteFormat::LittleEndian if IO::ByteFormat::LittleEndian.decode(Int32, bytes) == 3
    return IO::ByteFormat::BigEndian if IO::ByteFormat::BigEndian.decode(Int32, bytes) == 3

    rank = IO::ByteFormat::LittleEndian.decode(Int32, bytes)
    raise ParseException.new("Invalid gOpenMol file (rank is #{rank}, expected 3)")
  end
end
