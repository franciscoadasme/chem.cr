# Implementation based on [Chemfiles] C++ library.
#
# [Chemfiles]: https://github.com/chemfiles/chemfiles/blob/master/src/formats/DCD.cpp
@[Chem::RegisterFormat(ext: %w(.dcd), module_api: true)]
module Chem::DCD
  # Binary encoding for reading DCD content.
  struct Encoding
    # Byte order (big or little endian) of the DCD content.
    getter byte_format : IO::ByteFormat
    # Type of the block marker (32 or 64 bits).
    getter marker_type : Int32.class | Int64.class

    def initialize(@byte_format : IO::ByteFormat, @marker_type : Int32.class | Int64.class)
    end

    # Reads a value of the given type from *io* using the byte format.
    def read(io : IO, type : T.class) : T forall T
      io.read_bytes(type, @byte_format)
    end

    # Reads a block marker from *io*.
    def read_marker(io : IO) : Int32 | Int64
      io.read_bytes(@marker_type, @byte_format)
    end
  end

  # Info state needed for reading frames.
  record Info,
    buffer : Bytes,
    charmm_version : Int32,
    dim : Int32,
    encoding : Encoding,
    fixed_positions : Slice(Spatial::Vec3),
    n_atoms : Int32,
    n_frames : Int32,
    n_free_atoms : Int32,
    periodic : Bool,
    bytesize : Int64,
    title : String? do
    protected getter cell_block_bytesize : Int32 { periodic? ? marker_bytesize * 2 + 6 * sizeof(Float64) : 0 }
    protected getter first_frame_bytesize : Int32 { frame_bytesize(@n_atoms) }
    protected getter frame_bytesize : Int32 { frame_bytesize(@n_free_atoms) }
    protected getter marker_bytesize : Int32 { @encoding.marker_type == Int32 ? sizeof(Int32) : sizeof(Int64) }

    private def frame_bytesize(n_atoms : Int32) : Int32
      cell_block_bytesize + dim * (marker_bytesize * 2 + n_atoms * sizeof(Float32))
    end

    def periodic? : Bool
      @periodic
    end
  end

  # Yields each trajectory frame in *io*.
  def self.each(io : IO, & : Spatial::Positions3 ->) : Nil
    info = read_info(io)
    info.n_frames.times do |i|
      yield read(io, info)
    end
  end

  # :ditto:
  def self.each(path : Path | String, & : Spatial::Positions3 ->) : Nil
    File.open(path) do |file|
      each(file) do |pos|
        yield pos
      end
    end
  end

  # TODO: Implement iterator/indexable that holds io, info and read any frame.

  # Returns the first trajectory frame from *io*.
  # Use `read_all` or `each` for multiple.
  def self.read(io : IO, info : Info) : Spatial::Positions3
    offset = io.pos - info.bytesize
    index = offset // info.first_frame_bytesize
    index = (offset - info.first_frame_bytesize) // info.frame_bytesize + 1 if index > 1

    cell = read_cell(io, info) if info.periodic?

    size = index > 0 ? info.n_free_atoms : info.n_atoms
    # use pointer arithmetic to avoid indexing
    px, py, pz = read_positions(io, info, size).map &.to_unsafe.-(1)
    if index > 0 && info.n_free_atoms < info.n_atoms
      pos = info.fixed_positions.map_with_index do |vec, i|
        vec.nan? ? Spatial::Vec3[(px += 1).value, (py += 1).value, (pz += 1).value] : vec
      end
    else
      pos = Slice(Spatial::Vec3).new(info.n_atoms) do
        Spatial::Vec3[(px += 1).value, (py += 1).value, (pz += 1).value]
      end
    end

    Spatial::Positions3.new(pos, cell)
  end

  # Returns the trajectory frame at *index* from *io*.
  def self.read(io : IO, info : Info, index : Int) : Spatial::Positions3
    raise IndexError.new unless 0 <= index < info.n_frames
    new_pos = info.bytesize + info.first_frame_bytesize
    new_pos += (index - 1) * info.frame_bytesize if index > 0
    io.pos = new_pos
    read(io, info)
  end

  # Returns all trajectory frames in *io*.
  def self.read_all(io : IO) : Array(Spatial::Positions3)
    info = read_info(io)
    Array(Spatial::Positions3).new(info.n_frames) do |i|
      read(io, info)
    end
  end

  # :ditto:
  def self.read_all(path : Path | String) : Array(Spatial::Positions3)
    File.open(path) do |file|
      read_all(file)
    end
  end

  def self.read_info(io : IO) : Info
    encoding = detect_encoding(io)
    io.pos -= 4 # rewind "CORD"

    info_start = io.pos

    io.pos += 80
    charmm_version = encoding.read(io, Int32)

    io.pos = info_start + 4
    n_frames = encoding.read(io, Int32)
    start_frame = encoding.read(io, Int32)
    frame_step = encoding.read(io, Int32)

    io.pos += 20 # skip 20 unused bytes
    n_fixed_atoms = encoding.read(io, Int32)

    if charmm_version != 0
      timestep = encoding.read(io, Float32).to_f
      is_periodic = encoding.read(io, Int32) != 0
      dim = encoding.read(io, Int32) == 1 ? 4 : 3
      Log.warn { "Detected 4D DCD. Fourth dimension will be ignored." } if dim == 4
    else
      timestep = encoding.read(io, Float64)
      is_periodic = false
      dim = 3
    end

    io.pos = info_start + 84
    raise "Invalid end of info" unless encoding.read_marker(io) == 84

    title = read_title(io, encoding)
    n_atoms = read_block(io, encoding, sizeof(Int32)) { encoding.read(io, Int32) }
    n_free_atoms = n_atoms - n_fixed_atoms

    info_size = io.pos # here ends the header

    info = Info.new(
      buffer: Bytes.new(sizeof(Float32) * n_atoms * 3), # TODO: shrink to n_free_atoms whenever possible
      encoding: encoding,
      charmm_version: charmm_version,
      dim: dim,
      fixed_positions: Slice(Spatial::Vec3).empty,
      periodic: is_periodic,
      n_atoms: n_atoms,
      n_frames: n_frames,
      n_free_atoms: n_free_atoms,
      bytesize: info_size,
      title: title,
    )

    if n_fixed_atoms > 0
      fixed_positions = Slice(Float64).new(n_atoms * 3).unsafe_slice_of(Spatial::Vec3)
      read_block(io, encoding, sizeof(Int32) * n_free_atoms) do
        n_free_atoms.times do
          i = encoding.read(io, Int32) - 1
          raise "Invalid atom index #{i}" unless 0 <= i < n_atoms
          fixed_positions[i] = Spatial::Vec3::NAN
        end
      end

      info_size = io.pos # header now ends here

      io.pos += info.marker_bytesize * 2 + 6 * sizeof(Float64) if info.periodic? # skip unit cell block if present
      xx, yy, zz = read_positions(io, info, n_atoms)
      fixed_positions.zip(xx, yy, zz, 0...n_atoms) do |fixed_pos, x, y, z, i|
        fixed_positions[i] = Spatial::Vec3[x, y, z] unless fixed_pos.nan?
      end
      io.pos = info_size

      info = info.copy_with(fixed_positions: fixed_positions, bytesize: info_size)
    end

    if file = io.as?(File)
      body_bytesize = file.info.size - info.bytesize
      n_frames = (body_bytesize - info.first_frame_bytesize) // info.frame_bytesize + 1
      if n_frames != info.n_frames
        Log.warn { "Frame count mismatch (expected #{info.n_frames}, got #{n_frames})" }
        info = info.copy_with(n_frames: n_frames.to_i)
      end
    end

    info
  end

  # Writes a trajectory frame to *io*.
  #
  # The DCD must be initialized before writing frames, otherwise it will raise `ArgumentError`.
  # See `.write_info` for more details or `.write(io, frames, title)` for writing multiple frames.
  #
  # *buffer* may be used to avoid allocating a new slice for each frame.
  # It must be pre-allocated with the correct size.
  # Raises `ArgumentError` if the frame is empty or the buffer size is different from the frame size.
  #
  # NOTE: It does not check the written info, so the frame size must match the number of atoms and the periodic flag must be set correctly in the header.
  #
  # WARNING: The unit cell must be aligned to the XY plane, otherwise the atom coordinates might be misaligned.
  def self.write(io : IO, frame : Spatial::Positions3, buffer : Slice(Float32) = Slice(Float32).new(frame.size)) : Nil
    raise ArgumentError.new "DCD has not been initialized. Call write_info first" unless io.pos > 0
    raise ArgumentError.new "Cannot write an empty frame" if frame.size == 0
    raise ArgumentError.new "Cannot write frames with different size" if frame.size != buffer.size

    if cell = frame.cell?
      Log.warn do
        "The unit cell is not aligned to the XY plane for writing DCD. \
           Atom coordinates might not align with the cell."
      end unless cell.basis.lower_triangular?

      size = cell.size
      angles = cell.angles
      write_block(io, 6 * sizeof(Float64)) do
        io.write_bytes size[0]
        io.write_bytes angles[2]
        io.write_bytes size[1]
        io.write_bytes angles[1]
        io.write_bytes angles[0]
        io.write_bytes size[2]
      end
    end

    {% for component in %w(x y z) %}
      frame.each_with_index do |vec, j|
        buffer[j] = vec.{{component.id}}.to_f32
      end
      write_block(io, frame.size * sizeof(Float32)) do
        io.write(buffer.to_unsafe_bytes)
      end
    {% end %}
  end

  # Writes trajectory frames to *io*.
  #
  # This method is equivalent to calling `.write_info` and then `.write(io, frame, buffer)` for each frame.
  # If passed, *title* will be stored in the file info.
  #
  # It reuses the same buffer for all frames to avoid allocating a new slice for each frame.
  def self.write(io : IO, frames : Indexable(Spatial::Positions3), title : String? = nil) : Nil
    buffer = Slice(Float32).new frames[0].size
    write_info(io, frames.size, frames[0].size, !!frames[0].cell?, title)
    frames.each do |pos|
      write io, pos, buffer
    end
  end

  # :ditto:
  #
  # This is a generic implementation that works for any Enumerable, but it's less efficient than the indexable version.
  # It writes the number of frames (initially set to 0) in the header after writing all frames so it will fail for non-seekable IO.
  def self.write(io : IO, frames : Enumerable(Spatial::Positions3), title : String? = nil) : Nil
    buffer = Slice(Float32).empty
    n_atoms = 0
    n_frames = 0
    frames.each_with_index do |pos, i|
      if i == 0
        n_atoms = pos.size
        buffer = Slice(Float32).new(n_atoms)
        write_info(io, n_frames, n_atoms, !!pos.cell?, title)
      elsif pos.size != n_atoms
        raise ArgumentError.new "Cannot write positions of different size \
                                 (expected #{n_atoms}, got #{pos.size})"
      end
      write io, pos, buffer
      n_frames += 1
    end

    current = io.pos
    io.pos = 8 # the number of frames is always at offset 8 (1 marker + CORD)
    io.write_bytes n_frames
    io.pos = current
  end

  # Writes trajectory frames to the file at *path*.
  # It just opens the file and delegates it to `.write(io, frames, title)`.
  def self.write(path : Path | String, frames : Enumerable(Spatial::Positions3), title : String? = nil) : Nil
    File.open(path, "w") do |file|
      write(file, frames, title)
    end
  end

  # Writes the DCD header to *io*. Must be called before writing frames.
  #
  # *periodic* indicates if the unit cell will be written for each frame.
  # If true, all frames must have a unit cell.
  def self.write_info(io : IO, n_frames : Int32, n_atoms : Int32, periodic : Bool = true, title : String? = nil) : Nil
    write_block(io, 84) do
      io.write("CORD".to_slice)
      io.write_bytes(n_frames)         # number of frames
      io.write_bytes(0)                # frame start
      io.write_bytes(1)                # frame step
      io.write(Bytes.new(16))          # unused bytes
      io.write_bytes(3 * n_atoms)      # degrees of freedom
      io.write_bytes(0)                # number of fixed atoms
      io.write_bytes(0_f32)            # time step
      io.write_bytes(periodic ? 1 : 0) # includes unit cell
      io.write_bytes(0)                # 4D data
      io.write(Bytes.new(28))          # unused bytes
      io.write_bytes(24)               # CHARMM version
    end

    if title
      title = title.ljust((title.bytesize // 80 + 1) * 80) if title.bytesize % 80 != 0
      write_block(io, title.bytesize + sizeof(Int32)) do
        io.write_bytes(title.bytesize // 80)
        io.write(title.to_slice)
      end
    else
      write_block(io, sizeof(Int32)) do
        io.write_bytes(0)
      end
    end

    write_block(io, sizeof(Int32)) do
      io.write_bytes(n_atoms)
    end
  end

  private def self.detect_encoding(io : IO) : Encoding
    bytes = Bytes.new(8)
    io.read(bytes)

    if bytes[0..3] == UInt8.slice(84, 0, 0, 0)
      if bytes[4..7] == "CORD".to_slice
        return Encoding.new(IO::ByteFormat::LittleEndian, Int32)
      elsif bytes[4..7] == UInt8.slice(0, 0, 0, 0)
        extra = Bytes.new(4)
        io.read(extra)
        if extra == "CORD".to_slice
          return Encoding.new(IO::ByteFormat::LittleEndian, Int64)
        end
      end
    elsif bytes[0..2] == UInt8.slice(0, 0, 0)
      if bytes[3] == 84 && bytes[4..7] == "CORD".to_slice
        return Encoding.new(IO::ByteFormat::BigEndian, Int32)
      elsif bytes[3..7] == UInt8.slice(0, 0, 0, 0, 84)
        extra = Bytes.new(4)
        io.read(extra)
        if extra == "CORD".to_slice
          return Encoding.new(IO::ByteFormat::BigEndian, Int64)
        end
      end
    end

    raise "Invalid DCD (0x#{bytes[..3].join { |x| "%x" % x }} 0x#{bytes[4..].join { |x| "%x" % x }})"
  end

  private def self.read_block(io : IO, encoding : Encoding, marker : Int, & : -> T) : T forall T
    raise "Invalid start of block" unless encoding.read_marker(io) == marker
    value = yield
    raise "Invalid end of block" unless encoding.read_marker(io) == marker
    value
  end

  private def self.read_cell(io : IO, info : Info) : Spatial::Parallelepiped
    buffer = read_block(io, info.encoding, 6 * sizeof(Float64)) do
      StaticArray(Float64, 6).new do
        info.encoding.read(io, Float64)
      end
    end

    if info.charmm_version > 25
      i = Spatial::Vec3[buffer[0], buffer[1], buffer[3]]
      j = Spatial::Vec3[buffer[1], buffer[2], buffer[4]]
      k = Spatial::Vec3[buffer[3], buffer[4], buffer[5]]
      Spatial::Parallelepiped.new(i, j, k)
    else
      size = Spatial::Size3[buffer[0], buffer[2], buffer[5]]
      angles = {buffer[4], buffer[3], buffer[1]}
      if angles.all?(&.abs.<=(1)) # possibly saved as cos(angle)
        angles = angles.map { |cosangle| 90 - Math.asin(cosangle).degrees }
      end
      Spatial::Parallelepiped.new(size, angles)
    end
  end

  private def self.read_positions(io : IO, info : Info, size : Int32) : Tuple(Slice(Float32), Slice(Float32), Slice(Float32))
    bytesize = size * sizeof(Float32)
    slices = {0, 1, 2}.map { |i| info.buffer[i * bytesize, bytesize] }
    read_block(io, info.encoding, bytesize) { io.read_fully(slices[0]) }
    read_block(io, info.encoding, bytesize) { io.read_fully(slices[1]) }
    read_block(io, info.encoding, bytesize) { io.read_fully(slices[2]) }
    io.pos += info.marker_bytesize * 2 + bytesize if info.dim > 3 # skip 4th dimension if present
    if info.encoding.byte_format != IO::ByteFormat::SystemEndian
      slices.each do |slice|
        size.times do |i|
          slice[i * sizeof(Float32), sizeof(Float32)].reverse!
        end
      end
    end
    slices.map(&.unsafe_slice_of(Float32))
  end

  private def self.read_title(io : IO, encoding : Encoding) : String?
    bytesize = encoding.read_marker(io)
    title = nil
    if bytesize < 4 || (bytesize - 4) % 80 != 0
      io.seek(bytesize, :current) if bytesize != 0
      Log.warn { "Skipping title section due to invalid size" }
    else
      n_lines = encoding.read(io, Int32)
      if n_lines != (bytesize - 4) // 80
        io.seek(bytesize - 4, :current)
        Log.warn { "Skipping title section due to size mismatch" }
      else
        line_bytes = Bytes.new(80)
        title = String.build do |str|
          n_lines.times do
            line_bytes.fill(0)
            io.read(line_bytes)
            str.write line_bytes[0...line_bytes.index(0)]
            str << '\n'
          end
        end
      end
    end

    raise "Invalid end of title block" unless encoding.read_marker(io) == bytesize
    title
  end

  private def self.write_block(io : IO, marker : Int32, & : ->) : Nil
    io.write_bytes(marker)
    yield
    io.write_bytes(marker)
  end
end
