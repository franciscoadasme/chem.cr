# Implementation based on [Chemfiles] C++ library.
#
# [Chemfiles]: https://github.com/chemfiles/chemfiles/blob/master/src/formats/DCD.cpp
@[Chem::RegisterFormat(ext: %w(.dcd), module_api: true)]
module Chem::DCD
  # Yields each trajectory frame in *io*.
  def self.each(io : IO, & : Spatial::Positions3 ->) : Nil
    info = read_info(io)
    info.n_frames.times do |i|
      yield read_frame(io, info, i)
    end
  end

  # :ditto:
  def self.each(io : Path | String, & : Spatial::Positions3 ->) : Nil
    File.open(io) do |file|
      each(file) do |pos|
        yield pos
      end
    end
  end

  # TODO: Implement iterator/indexable that holds io, info and read any frame.

  # Returns the first trajectory frame from *io*.
  # Use `read_all` or `each` for multiple.
  #
  # TODO: it must accept the info. Reading only the first frame is useless and it leaves the IO in an inconsistent state without the info. It should just read the frame at the current location.
  def self.read(io : IO) : Spatial::Positions3
    read(io, 0)
  end

  # :ditto:
  #
  # TODO: remove overload. It makes no sense.
  def self.read(io : Path | String) : Spatial::Positions3
    File.open(io) do |file|
      read(file)
    end
  end

  # Returns the trajectory frame at *index* from *io*.
  #
  # TODO: it must accept the info (no need to read it). Perhaps info should holds the current frame index as io may not be at the beginning.
  def self.read(io : IO, index : Int) : Spatial::Positions3
    info = read_info(io)
    skip_to_frame(io, info, index)
    read_frame(io, info, index)
  end

  # :ditto:
  #
  # TODO: remove overload. It makes no sense.
  def self.read(io : Path | String, index : Int) : Spatial::Positions3
    File.open(io) { |file| read(file, index) }
  end

  # Returns all trajectory frames in *io*.
  def self.read_all(io : IO) : Array(Spatial::Positions3)
    info = read_info(io)
    Array(Spatial::Positions3).new(info.n_frames) do |i|
      read_frame(io, info, i)
    end
  end

  # :ditto:
  def self.read_all(io : Path | String) : Array(Spatial::Positions3)
    File.open(io) do |file|
      read_all(file)
    end
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

  # Info state needed for reading frames.
  record Info,
    byte_format : IO::ByteFormat,
    charmm_format : Bool,
    charmm_unitcell : Bool,
    charmm_version : Int32,
    dim : Int32,
    first_frame_bytesize : Int32,
    fixed_positions : Array(Spatial::Vec3?),
    frame_bytesize : Int32,
    marker_type : Int32.class | Int64.class,
    n_atoms : Int32,
    n_frames : Int32,
    n_free_atoms : Int32,
    size : Int64

  # TODO: this can be simply inlined as `raise message unless io.read_bytes(marker_type, byte_format) == expected`.
  # Using literals improves readability: `raise "Invalid end of info" unless io.read_bytes(marker_type, byte_format) == 84`
  private def self.check_marker(
    io : IO,
    marker_type : Int32.class | Int64.class,
    byte_format : IO::ByteFormat,
    expected : Int,
    message : String = "Expected marker %{expected}, got %{actual}",
  ) : Nil
    actual = io.read_bytes(marker_type, byte_format)
    raise message % {expected: expected.inspect, actual: actual.inspect} unless actual == expected
  end

  private def self.detect_encoding(io : IO) : Tuple(IO::ByteFormat, Int32.class | Int64.class)
    bytes = Bytes.new(8)
    io.read(bytes)

    if bytes[0..3] == UInt8.slice(84, 0, 0, 0)
      if bytes[4..7] == "CORD".to_slice
        return IO::ByteFormat::LittleEndian, Int32
      elsif bytes[4..7] == UInt8.slice(0, 0, 0, 0)
        extra = Bytes.new(4)
        io.read(extra)
        if extra == "CORD".to_slice
          return IO::ByteFormat::LittleEndian, Int64
        end
      end
    elsif bytes[0..2] == UInt8.slice(0, 0, 0)
      if bytes[3] == 84 && bytes[4..7] == "CORD".to_slice
        return IO::ByteFormat::BigEndian, Int32
      elsif bytes[3..7] == UInt8.slice(0, 0, 0, 0, 84)
        extra = Bytes.new(4)
        io.read(extra)
        if extra == "CORD".to_slice
          return IO::ByteFormat::BigEndian, Int64
        end
      end
    end

    raise "Invalid DCD (0x#{bytes[..3].join { |x| "%x" % x }} 0x#{bytes[4..].join { |x| "%x" % x }})"
  end

  private def self.read_block(
    io : IO,
    marker_type : Int32.class | Int64.class,
    byte_format : IO::ByteFormat,
    expected_size : Int? = nil,
    & : Int32 | Int64 -> T
  ) : T forall T
    marker = io.read_bytes(marker_type, byte_format)
    value = yield marker
    check_marker(io, marker_type, byte_format, marker.to_i, "Invalid end of block")
    value
  end

  private def self.read_block(
    io : IO,
    marker_type : Int32.class | Int64.class,
    byte_format : IO::ByteFormat,
    size : Int,
    & : -> T
  ) : T forall T
    check_marker(io, marker_type, byte_format, size, "Invalid start of block")
    value = yield
    check_marker(io, marker_type, byte_format, size, "Invalid end of block")
    value
  end

  private def self.read_cell(io : IO, info : Info) : Spatial::Parallelepiped
    marker_bytesize = info.marker_type == Int32 ? sizeof(Int32) : sizeof(Int64)
    arr = read_block(io, info.marker_type, info.byte_format, 6 * sizeof(Float64)) do
      StaticArray(Float64, 6).new { io.read_bytes(Float64, info.byte_format) }
    end

    if info.charmm_format && info.charmm_version > 25
      i = Spatial::Vec3[arr[0], arr[1], arr[3]]
      j = Spatial::Vec3[arr[1], arr[2], arr[4]]
      k = Spatial::Vec3[arr[3], arr[4], arr[5]]
      Spatial::Parallelepiped.new(i, j, k)
    else
      size = Spatial::Size3[arr[0], arr[2], arr[5]]
      angles = {arr[4], arr[3], arr[1]}
      if angles.all?(&.abs.<=(1)) # possibly saved as cos(angle)
        angles = angles.map { |cosangle| 90 - Math.asin(cosangle).degrees }
      end
      Spatial::Parallelepiped.new(size, angles)
    end
  end

  private def self.read_frame(io : IO, info : Info, entry_index : Int32) : Spatial::Positions3
    cell = read_cell(io, info) if info.charmm_unitcell

    x, y, z = read_positions(
      io, info.marker_type, info.byte_format, info.dim,
      info.n_atoms, info.fixed_positions, info.n_free_atoms, entry_index,
    )

    pos = Slice(Spatial::Vec3).new(info.n_atoms, Spatial::Vec3.zero)
    if info.fixed_positions.size > 0 && entry_index > 0
      j = -1
      info.fixed_positions.each_with_index do |fixed_pos, i|
        pos[i] = fixed_pos || Spatial::Vec3[x[(j += 1)], y[j], z[j]]
      end
    else
      info.n_atoms.times do |i|
        pos[i] = Spatial::Vec3[x[i], y[i], z[i]]
      end
    end

    Spatial::Positions3.new(pos, cell)
  end

  private def self.read_info(io : IO) : Info
    # TODO: detect_encoding should return an Enconding struct and then pass around instead of two separated values
    # TODO: Add Encoding.read(io, T) to replace io.read_bytes(T, encoding.byte_format) and Encoding.read_marker(io) to replace io.read_bytes(marker_type, byte_format)
    byte_format, marker_type = detect_encoding(io)
    io.pos -= 4 # rewind "CORD"

    info_start = io.pos

    io.pos += 80
    charmm_version = io.read_bytes(Int32, byte_format)
    charmm_format = charmm_version != 0

    io.pos = info_start + 4
    n_frames = io.read_bytes(Int32, byte_format)
    start_frame = io.read_bytes(Int32, byte_format)
    frame_step = io.read_bytes(Int32, byte_format)

    io.pos += 20 # skip 20 unused bytes
    n_fixed_atoms = io.read_bytes(Int32, byte_format)

    if charmm_format
      timestep = io.read_bytes(Float32, byte_format).to_f
      charmm_unitcell = io.read_bytes(Int32, byte_format) != 0
      dim = io.read_bytes(Int32, byte_format) == 1 ? 4 : 3
    else
      timestep = io.read_bytes(Float64, byte_format)
      charmm_unitcell = false
      dim = 3
    end

    io.pos = info_start + 84
    raise "Invalid end of info" unless io.read_bytes(marker_type, byte_format) == 84

    read_title(io, marker_type, byte_format)
    n_atoms = read_block(io, marker_type, byte_format, sizeof(Int32)) { io.read_bytes(Int32, byte_format) }
    buffer = Bytes.new(sizeof(Float32) * n_atoms * 3)

    info_size = io.pos

    n_free_atoms = n_atoms
    fixed_positions = [] of Spatial::Vec3?

    if n_fixed_atoms > 0
      n_free_atoms -= n_fixed_atoms
      fixed_positions = Array(Spatial::Vec3?).new(n_atoms) { Spatial::Vec3.zero }
      read_block(io, marker_type, byte_format, sizeof(Int32) * n_free_atoms) do
        n_free_atoms.times do
          i = io.read_bytes(Int32, byte_format)
          raise "Invalid atom index #{i}" unless 1 <= i <= n_atoms
          fixed_positions.unsafe_put(i - 1, nil)
        end
      end
      info_size = io.pos

      skip_block(io, marker_type, byte_format, 6 * sizeof(Float64)) if charmm_format && charmm_unitcell

      x, y, z = read_positions(io, marker_type, byte_format, dim, buffer, n_atoms, fixed_positions, 0)
      fixed_positions.map_with_index! do |pos, i|
        Spatial::Vec3[x[i], y[i], z[i]] if pos
      end

      io.pos = info_size
    end

    first_frame_bytesize, frame_bytesize = {n_atoms, n_free_atoms}.map do |size|
      coord_block_bytesize = (marker_type == Int32 ? sizeof(Int32) : sizeof(Int64)) * 2 + size * sizeof(Float32)
      bytesize = dim * coord_block_bytesize
      if charmm_format && charmm_unitcell
        cell_block_size = (marker_type == Int32 ? sizeof(Int32) : sizeof(Int64)) * 2 + 6 * sizeof(Float64)
        bytesize += cell_block_size
      end
      bytesize
    end

    if file = io.as?(File)
      body_bytesize = file.info.size - info_size
      actual_n_frames = (body_bytesize - first_frame_bytesize) // frame_bytesize + 1
      unless actual_n_frames == n_frames
        Log.warn { "Frame count mismatch (expected #{n_frames}, got #{actual_n_frames})" }
        n_frames = actual_n_frames.to_i32
      end
    end

    Info.new(
      byte_format: byte_format,
      charmm_format: charmm_format,
      charmm_unitcell: charmm_format && charmm_unitcell,
      charmm_version: charmm_version,
      dim: dim,
      first_frame_bytesize: first_frame_bytesize,
      fixed_positions: fixed_positions,
      frame_bytesize: frame_bytesize,
      marker_type: marker_type,
      n_atoms: n_atoms,
      n_frames: n_frames,
      n_free_atoms: n_free_atoms,
      size: info_size,
    )
  end

  private def self.read_positions(
    io : IO,
    marker_type : Int32.class | Int64.class,
    byte_format : IO::ByteFormat,
    dim : Int32,
    n_atoms : Int32,
    fixed_positions : Array(Spatial::Vec3?),
    n_free_atoms : Int32,
    entry_index : Int32,
  ) : Tuple(Slice(Float32), Slice(Float32), Slice(Float32))
    size = fixed_positions.size > 0 && entry_index > 0 ? n_free_atoms : n_atoms
    bytesize = size * sizeof(Float32)
    buffer = Bytes.new(n_atoms * sizeof(Float32) * 3)
    slices = StaticArray(Bytes, 3).new { |i| buffer[i * bytesize, bytesize] }

    read_block(io, marker_type, byte_format, bytesize) { io.read_fully(slices[0]) }
    read_block(io, marker_type, byte_format, bytesize) { io.read_fully(slices[1]) }
    read_block(io, marker_type, byte_format, bytesize) { io.read_fully(slices[2]) }
    skip_block(io, marker_type, byte_format, bytesize) if dim > 3
    unless byte_format == IO::ByteFormat::SystemEndian
      slices.each do |slice|
        size.times do |i|
          slice[i * sizeof(Float32), sizeof(Float32)].reverse!
        end
      end
    end

    {slices[0].unsafe_slice_of(Float32), slices[1].unsafe_slice_of(Float32), slices[2].unsafe_slice_of(Float32)}
  end

  private def self.read_positions(
    io : IO,
    marker_type : Int32.class | Int64.class,
    byte_format : IO::ByteFormat,
    dim : Int32,
    buffer : Bytes,
    n_atoms : Int32,
    fixed_positions : Array(Spatial::Vec3?),
    entry_index : Int32,
  ) : Tuple(Slice(Float32), Slice(Float32), Slice(Float32))
    size = fixed_positions.size > 0 && entry_index > 0 ? fixed_positions.count(&.nil?) : n_atoms
    bytesize = size * sizeof(Float32)
    slices = StaticArray(Bytes, 3).new { |i| buffer[i * bytesize, bytesize] }
    read_block(io, marker_type, byte_format, bytesize) { io.read_fully(slices[0]) }
    read_block(io, marker_type, byte_format, bytesize) { io.read_fully(slices[1]) }
    read_block(io, marker_type, byte_format, bytesize) { io.read_fully(slices[2]) }
    skip_block(io, marker_type, byte_format, bytesize) if dim > 3
    unless byte_format == IO::ByteFormat::SystemEndian
      slices.each do |slice|
        size.times do |i|
          slice[i * sizeof(Float32), sizeof(Float32)].reverse!
        end
      end
    end
    {slices[0].unsafe_slice_of(Float32), slices[1].unsafe_slice_of(Float32), slices[2].unsafe_slice_of(Float32)}
  end

  private def self.read_title(io : IO, marker_type : Int32.class | Int64.class, byte_format : IO::ByteFormat) : String?
    read_block(io, marker_type, byte_format) do |title_size|
      if title_size < 4 || (title_size - 4) % 80 != 0
        io.seek(title_size, :current) if title_size != 0
        Log.warn { "Skipping title section due to invalid size" }
        nil
      else
        n_lines = io.read_bytes(Int32, byte_format)
        if n_lines != (title_size - 4) // 80
          io.seek(title_size - 4, :current)
          Log.warn { "Skipping title section due to size mismatch" }
          nil
        else
          line_bytes = Bytes.new(80)
          String.build do |str|
            n_lines.times do
              line_bytes.fill(0)
              io.read(line_bytes)
              str.write line_bytes[0...line_bytes.index(0)]
              str << '\n'
            end
          end
        end
      end
    end
  end

  private def self.skip_block(io : IO, marker_type : Int32.class | Int64.class, byte_format : IO::ByteFormat, bytesize : Int) : Nil
    read_block(io, marker_type, byte_format, bytesize) { io.pos += bytesize }
  end

  private def self.skip_to_frame(io : IO, info : Info, index : Int) : Nil
    raise IndexError.new unless 0 <= index < info.n_frames
    return if index == 0
    new_pos = info.size + info.first_frame_bytesize + (index - 1).to_i64 * info.frame_bytesize
    io.pos = new_pos
  end

  private def self.write_block(io : IO, marker : Int32, & : ->) : Nil
    io.write_bytes(marker)
    yield
    io.write_bytes(marker)
  end
end
