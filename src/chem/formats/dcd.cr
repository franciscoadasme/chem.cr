@[Chem::RegisterFormat(ext: %w(.dcd))]
module Chem::DCD; end

# Implementation based on [Chemfiles] C++ library.
#
# [Chemfiles]: https://github.com/chemfiles/chemfiles/blob/master/src/formats/DCD.cpp
class Chem::DCD::Reader
  include FormatReader(Spatial::Positions3)
  include FormatReader::Indexable(Spatial::Positions3)

  @byte_format : IO::ByteFormat = IO::ByteFormat::SystemEndian
  @buffer = Bytes.empty
  @charmm_format = false
  @charmm_unitcell = false
  @charmm_version = 0
  @first_frame_bytesize = 0
  @fixed_positions = [] of Spatial::Vec3?
  @frame_bytesize = 0
  @dim = 3
  @header_size = 0
  @marker_type : Int32.class | Int64.class = Int32
  @n_atoms = 0
  @n_free_atoms = 0
  @start_frame = 0
  @frame_step = 0
  @timestep = 0.0
  @title : String?

  getter entry_index : Int32 = 0
  getter n_entries : Int32 = 0

  def initialize(
    @io : IO,
    @sync_close : Bool = false,
  )
    detect_encoding
    read_header
  end

  protected def decode_entry : Spatial::Positions3
    cell = read_cell if @charmm_format && @charmm_unitcell

    x, y, z = read_positions
    pos = Slice(Spatial::Vec3).new @n_atoms, Spatial::Vec3.zero
    if @fixed_positions.size > 0 && @entry_index > 0
      j = -1
      @fixed_positions.each_with_index do |fixed_pos, i|
        pos[i] = fixed_pos || Spatial::Vec3[x[(j += 1)], y[j], z[j]]
      end
    else
      @n_atoms.times do |i|
        pos[i] = Spatial::Vec3[x[i], y[i], z[i]]
      end
    end

    Spatial::Positions3.new pos, cell
  end

  def skip_to_entry(index : Int) : Nil
    check_open
    raise IndexError.new unless 0 <= index < @n_entries
    new_pos = @header_size
    new_pos += @first_frame_bytesize + (index - 1) * @frame_bytesize
    @io.pos = new_pos
    @entry_index = index
  end

  private def detect_encoding
    byte_format = nil

    bytes = Bytes.new(8)
    @io.read(bytes)

    if bytes[0..3] == UInt8.slice(84, 0, 0, 0)
      if bytes[4..7] == "CORD".to_slice
        @marker_type = Int32
        byte_format = IO::ByteFormat::LittleEndian
      elsif bytes[4..7] == UInt8.slice(0, 0, 0, 0)
        extra = Bytes.new(4)
        @io.read(extra)
        if extra == "CORD".to_slice
          @marker_type = Int64
          byte_format = IO::ByteFormat::LittleEndian
        end
      end
    elsif bytes[0..2] == UInt8.slice(0, 0, 0)
      if bytes[3] == 84 && bytes[4..7] == "CORD".to_slice
        @marker_type = Int32
        byte_format = IO::ByteFormat::BigEndian
      elsif bytes[3..7] == UInt8.slice(0, 0, 0, 0, 84)
        extra = Bytes.new(4)
        @io.read(extra)
        if extra == "CORD".to_slice
          @marker_type = Int64
          byte_format = IO::ByteFormat::BigEndian
        end
      end
    end

    if byte_format
      @byte_format = byte_format
      @io.pos -= 4 # rewind "CORD"
    else
      raise "Invalid DCD (0x#{bytes[..3].join { |x| "%x" % x }} 0x#{bytes[4..].join { |x| "%x" % x }})"
    end
  end

  private def expect_marker(
    expected : Int,
    message : String = "Expected marker %{expected}, got %{actual}",
  ) : Nil
    unless (actual = read_marker) == expected
      raise message % {expected: expected.inspect, actual: actual.inspect}
    end
  end

  private def marker_bytesize : Int32
    @marker_type == Int32 ? sizeof(Int32) : sizeof(Int64)
  end

  private def read(type : T.class) : T forall T
    @io.read_bytes type, @byte_format
  end

  private def read_block(name : String, & : Int32 | Int64 -> T) : T forall T
    marker = read_marker
    value = yield marker
    expect_marker marker, "Invalid end of #{name}"
    value
  end

  private def read_block(name : String, marker : Int, & : -> T) : T forall T
    expect_marker marker, "Invalid start of #{name}"
    value = yield
    expect_marker marker, "Invalid end of #{name}"
    value
  end

  private def read_cell : Spatial::Parallelepiped
    arr = read_block("unit cell", 6 * sizeof(Float64)) do
      StaticArray(Float64, 6).new { read Float64 }
    end

    if @charmm_format && @charmm_version > 25
      i = Spatial::Vec3[arr[0], arr[1], arr[3]]
      j = Spatial::Vec3[arr[1], arr[2], arr[4]]
      k = Spatial::Vec3[arr[3], arr[4], arr[5]]
      Spatial::Parallelepiped.new i, j, k
    else
      size = Spatial::Size3[arr[0], arr[2], arr[5]]
      angles = {arr[4], arr[3], arr[1]}
      if angles.all?(&.abs.<=(1)) # possibly saved as cos(angle)
        angles = angles.map do |cosangle|
          90 - Math.asin(cosangle).degrees
        end
      end
      Spatial::Parallelepiped.new size, angles
    end
  end

  private def read_header : Nil
    header_start = @io.pos

    @io.pos += 80
    @charmm_version = read(Int32)
    @charmm_format = @charmm_version != 0

    @io.pos = header_start + 4
    @n_entries = read(Int32)
    @start_frame = read(Int32)
    @frame_step = read(Int32)

    @io.pos += 20 # skip 20 unused bytes
    n_fixed_atoms = read(Int32)

    if @charmm_format
      @timestep = read(Float32).to_f

      @charmm_unitcell = read(Int32) != 0
      @dim = 4 if read(Int32) == 1
    else
      @timestep = read(Float64)
    end

    @io.pos = header_start + 84
    expect_marker 84, "Invalid end of header"

    @title = read_title
    @n_atoms = read_block("number of atoms", sizeof(Int32)) { read(Int32) }
    @buffer = Bytes.new sizeof(Float32) * @n_atoms * 3

    @header_size = @io.pos

    @n_free_atoms = @n_atoms
    if n_fixed_atoms > 0
      @n_free_atoms -= n_fixed_atoms
      @fixed_positions = Array(Spatial::Vec3?).new(@n_atoms) { Spatial::Vec3.zero }
      read_block("free atoms", sizeof(Int32) * @n_free_atoms) do
        @n_free_atoms.times do
          i = read(Int32)
          raise "Invalid atom index #{i}" unless 1 <= i <= @n_atoms
          @fixed_positions.unsafe_put i - 1, nil
        end
      end
      @header_size = @io.pos

      skip_block("unit cell", 6 * sizeof(Float64)) if @charmm_format && @charmm_unitcell

      x, y, z = read_positions
      @fixed_positions.map_with_index! do |pos, i|
        Spatial::Vec3[x[i], y[i], z[i]] if pos
      end

      @io.pos = @header_size
    end

    @first_frame_bytesize, @frame_bytesize = {@n_atoms, @n_free_atoms}.map do |size|
      coord_block_bytesize = marker_bytesize * 2 + size * sizeof(Float32)
      bytesize = @dim * coord_block_bytesize
      if @charmm_format && @charmm_unitcell
        cell_block_size = marker_bytesize * 2 + 6 * sizeof(Float64)
        bytesize += cell_block_size
      end
      bytesize
    end
    if file = @io.as?(File)
      body_bytesize = file.info.size - @header_size
      actual_n_frames = (body_bytesize - @first_frame_bytesize) // @frame_bytesize + 1
      unless actual_n_frames == @n_entries
        Log.warn { "Frame count mismatch (expected #{@n_entries}, got #{actual_n_frames})" }
        @n_entries = actual_n_frames.to_i32
      end
    end
  end

  private def read_marker : Int32 | Int64
    @io.read_bytes(@marker_type, @byte_format)
  end

  private def read_positions : StaticArray(Slice(Float32), 3)
    # frame may include only positions for free atoms (n) instead of all
    # atoms (N) after the first frame
    size = @fixed_positions.size > 0 && @entry_index > 0 ? @n_free_atoms : @n_atoms
    bytesize = size * sizeof(Float32)
    # X, Y, and Z coordinates are saved as contiguous blocks (3*n), so
    # split the buffer into three n-sized slices.
    slices = StaticArray(Bytes, 3).new { |i| @buffer[i * bytesize, bytesize] }
    read_block("x", bytesize) { @io.read_fully slices[0] }
    read_block("y", bytesize) { @io.read_fully slices[1] }
    read_block("z", bytesize) { @io.read_fully slices[2] }
    skip_block("4d", bytesize) if @dim > 3
    unless @byte_format == IO::ByteFormat::SystemEndian
      slices.each do |slice|
        size.times do |i|
          slice[i * sizeof(Float32), sizeof(Float32)].reverse!
        end
      end
    end
    slices.map &.unsafe_slice_of(Float32)
  end

  private def read_title : String?
    read_block("title") do |title_size|
      title = nil
      if title_size < 4 || (title_size - 4) % 80 != 0
        if title_size != 0
          Log.warn { "Skipping title section due to invalid size" }
          @io.seek title_size, IO::Seek::Current
        end
      else
        n_lines = @io.read_bytes(Int32, @byte_format)
        if n_lines != (title_size - 4) // 80
          Log.warn { "Skipping title section due to size mismatch" }
          @io.seek title_size - 4, IO::Seek::Current
        else
          line_bytes = Bytes.new 80
          title = String.build do |str|
            n_lines.times do
              line_bytes.fill 0
              @io.read(line_bytes)
              str.write line_bytes[0...line_bytes.index(0)]
              str << '\n'
            end
          end
        end
      end
      title
    end
  end

  private def skip_block(name : String, bytesize : Int) : Nil
    read_block(name, bytesize) do
      @io.pos += bytesize
    end
  end
end

class Chem::DCD::Writer
  include FormatWriter(Spatial::Positions3)
  include FormatWriter::MultiEntry(Spatial::Positions3)

  @buffer : Slice(Float32)
  @size : Int32

  def initialize(
    @io : IO,
    @total_entries : Int32? = nil,
    @title : String? = nil,
    @sync_close : Bool = false,
  )
    check_total_entries
    @buffer = Slice(Float32).empty
    @size = 0
  end

  protected def encode_entry(obj : Spatial::Positions3) : Nil
    raise ArgumentError.new "Cannot write empty positions" if obj.size == 0
    if !@written
      @size = obj.size
      @buffer = Slice(Float32).new @size
      write_header !!obj.cell?
    elsif obj.size != @size
      raise ArgumentError.new "Cannot write positions of different size \
                               (expected #{@size}, got #{obj.size})"
    end
    if cell = obj.cell?
      write_cell cell
    end
    write_positions obj
    update_frames
  end

  private def update_frames : Nil
    current = @io.pos
    @io.pos = 8 # the number of frames is always at offset 8 (1 marker + CORD)
    @io.write_bytes @entry_index + 1
    @io.pos = current
  end

  private def write_block(marker : T.class, count : Int, & : ->) : Nil forall T
    write_block(count * sizeof(T)) do
      yield
    end
  end

  private def write_block(marker : T.class, & : ->) : Nil forall T
    write_block(sizeof(T)) do
      yield
    end
  end

  private def write_block(marker : Int, & : ->) : Nil
    marker = marker.to_i32
    @io.write_bytes marker
    yield
    @io.write_bytes marker
  end

  private def write_cell(cell : Spatial::Parallelepiped) : Nil
    if !cell.basis.lower_triangular? # not aligned to XY
      Log.warn do
        "The unit cell is not aligned to the XY plane for writing DCD. \
          Atom coordinates might not align with the cell."
      end
    end
    size = cell.size
    angles = cell.angles
    write_block(Float64, 6) do
      @io.write_bytes size[0]
      @io.write_bytes angles[2]
      @io.write_bytes size[1]
      @io.write_bytes angles[1]
      @io.write_bytes angles[0]
      @io.write_bytes size[2]
    end
  end

  private def write_header(has_unitcell : Bool) : Nil
    write_block(84) do
      @io.write "CORD".to_slice
      @io.write_bytes 0 # number of frames (updated after writing every frame)
      @io.write_bytes 0 # frame start
      @io.write_bytes 1 # frame step

      @io.write Bytes.new(16) # unused bytes

      @io.write_bytes 3 * @size # degrees of freedom
      @io.write_bytes 0         # number of fixed atoms
      @io.write_bytes 0_f32     # time step

      @io.write_bytes has_unitcell ? 1 : 0
      @io.write_bytes 0 # 4D data

      @io.write Bytes.new(28) # unused bytes

      @io.write_bytes 24 # CHARMM version
    end

    if title = @title
      title = title.ljust((title.bytesize // 80 + 1) * 80) if title.bytesize % 80 != 0
      write_block(title.bytesize + sizeof(Int32)) do
        @io.write_bytes title.bytesize // 80
        @io.write title.to_slice
      end
    else
      write_block(Int32) do
        @io.write_bytes 0
      end
    end

    write_block(Int32) do
      @io.write_bytes @size # number of atoms
    end
  end

  private def write_positions(pos : Spatial::Positions3) : Nil
    {% for component in %w(x y z) %}
      pos.each_with_index do |vec, i|
        @buffer[i] = vec.{{component.id}}.to_f32
      end
      write_block(Float32, @size) do
        @io.write @buffer.to_unsafe_bytes
      end
    {% end %}
  end
end
