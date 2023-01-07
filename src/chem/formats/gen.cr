@[Chem::RegisterFormat(ext: %w(.gen))]
module Chem::Gen
  class Reader
    include FormatReader(Structure)

    def initialize(
      @io : IO,
      @guess_bonds : Bool = false,
      @guess_names : Bool = false,
      @sync_close : Bool = false
    )
      @pull = PullParser.new(@io)
    end

    private def decode_entry : Structure
      raise IO::EOFError.new if @pull.eof?

      n_atoms = @pull.next_i
      fractional = periodic = false
      case @pull.next_s
      when "F" then fractional = periodic = true
      when "S" then periodic = true
      when "C" then fractional = periodic = false
      else          @pull.error("Invalid geometry type")
      end
      @pull.next_line

      ele_map = [] of Element
      while str = @pull.next_s?
        element = PeriodicTable[str]? || @pull.error("Unknown element")
        ele_map << element
      end
      @pull.next_line

      structure = Structure.build(
        guess_bonds: @guess_bonds,
        guess_names: @guess_names,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
        use_templates: false,
      ) do |builder|
        n_atoms.times do
          @pull.next_s? # skip atom number
          ele = ele_map[@pull.next_i - 1]?
          @pull.error "Invalid element index (expected 1 to #{ele_map.size})" unless ele
          vec = Spatial::Vec3.new @pull.next_f, @pull.next_f, @pull.next_f
          @pull.next_line
          builder.atom ele, vec
        end
      end

      if periodic
        @pull.next_line # skip first unit cell line
        vi = Spatial::Vec3.new @pull.next_f, @pull.next_f, @pull.next_f
        @pull.next_line
        vj = Spatial::Vec3.new @pull.next_f, @pull.next_f, @pull.next_f
        @pull.next_line
        vk = Spatial::Vec3.new @pull.next_f, @pull.next_f, @pull.next_f
        @pull.next_line
        structure.cell = Spatial::Parallelepiped.new vi, vj, vk
        structure.coords.to_cart! if fractional
      end

      structure
    end
  end

  class Writer
    include FormatWriter(AtomCollection)

    def initialize(@io : IO,
                   @fractional : Bool = false,
                   @sync_close : Bool = false)
    end

    protected def encode_entry(obj : AtomCollection) : Nil
      cell = obj.cell? if obj.is_a?(Structure)
      raise Spatial::NotPeriodicError.new if @fractional && cell.nil?

      ele_table = obj.each_atom.map(&.element).uniq.with_index.to_h
      geometry_type = @fractional ? 'F' : (cell ? 'S' : 'C')

      @io.printf "%5d%3s\n", obj.n_atoms, geometry_type
      ele_table.each_key { |ele| @io.printf "%3s", ele.symbol }
      @io.puts

      obj.each_atom.with_index do |atom, i|
        ele = ele_table[atom.element] + 1
        vec = atom.coords
        vec = cell.not_nil!.fract vec if @fractional
        @io.printf "%5d%2s%20.10E%20.10E%20.10E\n", i + 1, ele, vec.x, vec.y, vec.z
      end

      write cell if cell
    end

    private def write(cell : Spatial::Parallelepiped) : Nil
      ({Spatial::Vec3.zero} + cell.basisvec).each do |vec|
        @io.printf "%20.10E%20.10E%20.10E\n", vec.x, vec.y, vec.z
      end
    end
  end
end
