# Implementation based on [Chemfiles] C++ library.
#
# [Chemfiles]: https://github.com/chemfiles/chemfiles/blob/master/src/formats/DCD.cpp
class Chem::DCD::Reader
  include FormatReader(Structure)
  include FormatReader::Indexable(Structure)

  @byte_format : IO::ByteFormat = IO::ByteFormat::SystemEndian
  @charmm_format = false
  @charmm_unitcell = false
  @charmm_version = 0
  @first_frame_size = 0
  @fixed_positions = [] of Spatial::Vec3?
  @frame_size = 0
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
    @structure : Structure,
    @reuse : Bool = false,
    @sync_close : Bool = false
  )
    detect_encoding
    read_header
    unless @n_atoms == @structure.atoms.size
      raise "DCD content is incompatible with #{@structure}"
    end
  end

  protected def decode_entry : Structure
    structure = @reuse ? @structure : @structure.clone
    if @timestep > 0 && @frame_step > 0
      structure.metadata["time"] = (@start_frame + @entry_index * @frame_step) * @timestep
    end
    structure.title = @title || ""
    structure.cell = read_cell if @charmm_format && @charmm_unitcell

    atoms = structure.atoms

    n_atoms = @n_atoms
    if !@fixed_positions.empty? && @entry_index > 0
      n_atoms = @n_free_atoms
      atoms.zip(@fixed_positions) do |atom, pos|
        atom.coords = pos if pos
      end
    end


    bytesize = sizeof(Float32) * n_atoms
    read_block("x", bytesize) do
      if n_atoms == @n_atoms
        atoms.each do |atom|
          atom.coords = Spatial::Vec3[read_f32, 0, 0]
        end
      else
        atoms.zip(@fixed_positions) do |atom, fixed_pos|
          atom.coords = fixed_pos || Spatial::Vec3[read_f32, 0, 0]
        end
      end
    end

    read_block("y", bytesize) do
      if n_atoms == @n_atoms
        atoms.each do |atom|
          atom.coords = Spatial::Vec3[atom.coords.x, read_f32, 0]
        end
      else
        atoms.zip(@fixed_positions) do |atom, fixed_pos|
          atom.coords = fixed_pos || Spatial::Vec3[atom.x, read_f32, 0]
        end
      end
    end

    read_block("z", bytesize) do
      if n_atoms == @n_atoms
        atoms.each do |atom|
          atom.coords = Spatial::Vec3[atom.x, atom.y, read_f32]
        end
      else
        atoms.zip(@fixed_positions) do |atom, fixed_pos|
          atom.coords = fixed_pos || Spatial::Vec3[atom.x, atom.y, read_f32]
        end
      end
    end

    skip_block "4d", bytesize if @dim > 3

    structure
  end

  def skip_to_entry(index : Int) : Nil
    check_open
    raise IndexError.new unless 0 <= index < @n_entries
    new_pos = @header_size
    new_pos += @first_frame_size + (index - 1) * @frame_size
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

  private def compute_frame_size(n_atoms : Int32) : Int32
    coord_block_bytesize = marker_bytesize * 2 + n_atoms * sizeof(Float32)
    size = @dim * coord_block_bytesize
    if @charmm_format && @charmm_unitcell
      cell_block_size = marker_bytesize * 2 + 6 * sizeof(Float64)
      size += cell_block_size
    end
    size
  end

  private def expect_marker(
    expected : Int,
    message : String = "Expected marker %{expected}, got %{actual}"
  ) : Nil
    unless (actual = read_marker) == expected
      raise message % {expected: expected.inspect, actual: actual.inspect}
    end
  end

  private def marker_bytesize : Int32
    @marker_type == Int32 ? sizeof(Int32) : sizeof(Int64)
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
      Array(Float64).new(6) { read_float }
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

  private def read_f32 : Float32
    @io.read_bytes Float32, @byte_format
  end

  private def read_float : Float64
    @io.read_bytes Float64, @byte_format
  end

  private def read_header : Nil
    header_start = @io.pos

    @io.pos += 80
    @charmm_version = read_int
    @charmm_format = @charmm_version != 0

    @io.pos = header_start + 4
    @n_entries = read_int
    @start_frame = read_int
    @frame_step = read_int

    @io.pos += 20 # skip 20 unused bytes
    n_fixed_atoms = read_int

    if @charmm_format
      @timestep = read_f32.to_f

      @charmm_unitcell = read_int != 0
      @dim = 4 if read_int == 1
    else
      @timestep = read_float
    end

    @io.pos = header_start + 84
    expect_marker 84, "Invalid end of header"

    @title = read_title
    @n_atoms = read_block("number of atoms", sizeof(Int32)) { read_int }

    @header_size = @io.pos

    @n_free_atoms = @n_atoms
    if n_fixed_atoms > 0
      @n_free_atoms = @n_atoms - n_fixed_atoms
      @fixed_positions = Array(Spatial::Vec3?).new(@n_atoms) { Spatial::Vec3.zero }
      read_block("free atoms", sizeof(Int32) * @n_free_atoms) do
        @n_free_atoms.times do
          i = read_int
          raise "Invalid atom index #{i}" unless 1 <= i <= @n_atoms
          @fixed_positions.unsafe_put i - 1, nil
        end
      end
      @header_size = @io.pos

      skip_block("unit cell", 6 * sizeof(Float64)) if @charmm_format && @charmm_unitcell

      bytesize = sizeof(Float32) * @n_atoms
      x = read_block("x", bytesize) { Array(Float32).new(@n_atoms) { read_f32 } }
      y = read_block("y", bytesize) { Array(Float32).new(@n_atoms) { read_f32 } }
      z = read_block("z", bytesize) { Array(Float32).new(@n_atoms) { read_f32 } }
      skip_block("4d", bytesize) if @dim > 3

      @fixed_positions.map_with_index! do |pos, i|
        Spatial::Vec3[x.unsafe_fetch(i), y.unsafe_fetch(i), z.unsafe_fetch(i)] if pos
      end

      @io.pos = @header_size
    end

    @first_frame_size = compute_frame_size(@n_atoms)
    @frame_size = compute_frame_size(@n_free_atoms)
    if file = @io.as?(File)
      body_size = file.info.size - @header_size
      actual_n_frames = (body_size - @first_frame_size) // @frame_size + 1
      unless actual_n_frames == @n_entries
        Log.warn { "Frame count mistmatch (expected #{@n_entries}, got #{actual_n_frames})" }
        @n_entries = actual_n_frames.to_i32
      end
    end
  end

  private def read_int : Int32
    @io.read_bytes Int32, @byte_format
  end

  private def read_marker : Int32 | Int64
    @io.read_bytes(@marker_type, @byte_format)
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
    read_block("4d", bytesize) do
      @io.pos += bytesize
    end
  end
end
