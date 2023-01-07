@[Chem::RegisterFormat(ext: %w(.poscar), names: %w(POSCAR* CONTCAR*))]
module Chem::VASP::Poscar
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

      title = @pull.line.strip
      @pull.next_line
      scale_factor = @pull.next_f
      @pull.next_line

      # read unit cell
      vi = Spatial::Vec3.new @pull.next_f, @pull.next_f, @pull.next_f
      @pull.next_line
      vj = Spatial::Vec3.new @pull.next_f, @pull.next_f, @pull.next_f
      @pull.next_line
      vk = Spatial::Vec3.new @pull.next_f, @pull.next_f, @pull.next_f
      @pull.next_line
      cell = Spatial::Parallelepiped.new(vi * scale_factor, vj * scale_factor, vk * scale_factor)

      # read species
      uniq_elements = [] of Element
      while (str = @pull.next_s?) && str[0].ascii_letter?
        ele = PeriodicTable[str]? || @pull.error("Unknown element")
        uniq_elements << ele
      end
      @pull.error("Missing atom species") if uniq_elements.empty?
      @pull.next_line

      # read atom count
      elements = [] of Element
      uniq_elements.map do |ele|
        if count = @pull.next_i?
          count.times { elements << ele }
        else
          @pull.error "Couldn't read number of atoms for #{ele.symbol}"
        end
      end
      @pull.next_line

      # read selective dynamics flag
      constrained = false
      @pull.next_token
      if @pull.char.in?('s', 'S')
        constrained = true
        @pull.next_line
        @pull.next_token
      end

      # read coordinate system (cartesian or direct)
      fractional = false
      case @pull.char
      when 'C', 'c', 'K', 'k' # cartesian
        fractional = false
      when 'D', 'd' # direct
        fractional = true
      else
        @pull.error "Invalid coordinate system"
      end
      @pull.next_line

      Structure.build(
        guess_bonds: @guess_bonds,
        guess_names: @guess_names,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
        use_templates: false,
      ) do |builder|
        builder.title title
        builder.cell cell
        elements.each do |element|
          vec = Spatial::Vec3.new @pull.next_f, @pull.next_f, @pull.next_f
          vec = fractional ? cell.cart(vec) : vec * scale_factor
          atom = builder.atom element, vec
          if constrained
            case {read_flag, read_flag, read_flag}
            when {false, true, true}   then atom.constraint = :x
            when {true, false, true}   then atom.constraint = :y
            when {true, true, false}   then atom.constraint = :z
            when {false, false, true}  then atom.constraint = :xy
            when {false, true, false}  then atom.constraint = :xz
            when {true, false, false}  then atom.constraint = :yz
            when {false, false, false} then atom.constraint = :xyz
            end
          end
          @pull.next_line
        end
      end
    end

    private def read_flag : Bool
      @pull.next_token
      case @pull.char
      when 'T' then true
      when 'F' then false
      else          @pull.error "Invalid boolean flag (expected either T or F)"
      end
    end
  end

  class Writer
    include FormatWriter(Structure)

    @ele_order : Array(Element)?

    def initialize(@io : IO,
                   order : Array(Element) | Array(String) | Nil = nil,
                   @fractional : Bool = false,
                   @wrap : Bool = false,
                   @sync_close : Bool = false)
      order = order.map { |sym| PeriodicTable[sym] } if order.is_a?(Array(String))
      @ele_order = order
    end

    protected def encode_entry(obj : Structure) : Nil
      raise Spatial::NotPeriodicError.new unless cell = obj.cell?

      atoms = obj.atoms
      coordinate_system = @fractional ? "Direct" : "Cartesian"
      ele_tally = count_elements atoms
      has_constraints = atoms.any? &.constraint

      @io.puts obj.title.gsub(/ *\n */, ' ')
      write cell
      write_elements ele_tally
      @io.puts "Selective dynamics" if has_constraints
      @io.puts coordinate_system

      ele_tally.each do |ele, _|
        atoms.each.select(&.element.==(ele)).each do |atom|
          vec = atom.coords
          if @fractional
            vec = cell.fract vec
            vec = vec.wrap if @wrap
          elsif @wrap
            vec = cell.wrap vec
          end

          @io.printf "%22.16f%22.16f%22.16f", vec.x, vec.y, vec.z
          write atom.constraint || Constraint::None if has_constraints
          @io.puts
        end
      end
    end

    private def count_elements(atoms : Enumerable(Atom)) : Array(Tuple(Element, Int32))
      ele_tally = atoms.map(&.element).tally.to_a
      if order = @ele_order
        ele_tally.sort_by! do |(k, _)|
          order.index(k) || raise ArgumentError.new "#{k} not found in specified order"
        end
      end
      ele_tally
    end

    private def write(constraint : Constraint) : Nil
      {:x, :y, :z}.each do |axis|
        @io.printf "%4s", axis.in?(constraint) ? 'F' : 'T'
      end
    end

    private def write(cell : Spatial::Parallelepiped) : Nil
      @io.printf " %18.14f\n", 1.0
      cell.basisvec.each do |vec|
        @io.printf " %22.16f%22.16f%22.16f\n", vec.x, vec.y, vec.z
      end
    end

    private def write_elements(ele_table) : Nil
      ele_table.each { |(ele, _)| @io.printf "%5s", ele.symbol.ljust(2) }
      @io.puts
      ele_table.each { |(_, count)| @io.printf "%6d", count }
      @io.puts
    end
  end
end
