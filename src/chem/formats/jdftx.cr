@[Chem::RegisterFormat(ext: %w(.ionpos .lattice))]
module Chem::JDFTx
  class Reader
    include FormatReader(Structure)

    def initialize(
      @io : IO,
      @guess_bonds : Bool = false,
      @guess_names : Bool = false,
      @sync_close : Bool = false
    )
    end

    protected def decode_entry : Structure
      fractional = false
      lattice_scale = {1.0, 1.0, 1.0}
      cell = nil
      structure = Structure.build(
        guess_bonds: @guess_bonds,
        guess_names: @guess_names,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
        use_templates: false,
      ) do |builder|
        @io.gets_to_end.gsub(/\s*\\\s*\n\s*/, ' ').each_line do |line|
          tokens = line.split
          case tokens.first?
          when "ion"
            element = PeriodicTable[tokens[1]]
            pos = Spatial::Vec3[*tokens[{2, 3, 4}].map(&.to_f)]
            pos = pos.map(&.bohrs) unless fractional
            atom = builder.atom element, pos
            tokens.delete_at 5..8 if tokens[5] == "v" # ignore velocity if present
            atom.constraint = :xyz if tokens[5].to_f == 0
          when "coords-type"
            fractional = tokens[1].downcase == "lattice"
          when "latt-scale"
            lattice_scale = tokens[{1, 2, 3}].map &.to_f
          when "lattice"
            cell = parse_cell(line)
          end
        end

        if file = @io.as?(File)
          path = Path[file.path]
          path = path.sibling "#{path.stem}.lattice"
          if File.exists?(path)
            cell = parse_cell File.read(path).gsub(/\s*\\\s*\n\s*/, ' ')
          end
        end

        builder.cell cell if cell
      end

      cell = cell.try &.scale(*lattice_scale)
      if fractional
        raise "Missing command lattice" unless cell
        structure.coords.to_cart!
      end

      structure
    end

    private def parse_cell(line : String) : Spatial::Parallelepiped
      tokens = line.split
      case tokens[1].downcase
      when "monoclinic"
        a, _, c = tokens[1..3].map(&.to_f.bohrs)
        beta = tokens[4].to_f
        Spatial::Parallelepiped.monoclinic(a, c, beta)
      when "triclinic"
        lengths = {1, 2, 3}.map { |i| tokens[i].to_f.bohrs }
        angles = {4, 5, 6}.map { |i| tokens[i].to_f }
        Spatial::Parallelepiped.new(lengths, angles)
      when "orthorhombic"
        a, b, c = tokens[1..3].map(&.to_f.bohrs)
        Spatial::Parallelepiped.orthorhombic(a, b, c)
      when "tetragonal"
        a, c = tokens[1..2].map(&.to_f.bohrs)
        Spatial::Parallelepiped.tetragonal(a, c)
      when "hexagonal"
        a, c = tokens[1..2].map(&.to_f.bohrs)
        Spatial::Parallelepiped.hexagonal(a, c)
      when "rhombohedral"
        a = tokens[1].to_f.bohrs
        alpha = tokens[2].to_f
        Spatial::Parallelepiped.rhombohedral(a, alpha)
      when "cubic"
        size = tokens[1].to_f.bohrs
        Spatial::Parallelepiped.cubic(size)
      else
        values = tokens[1..9].map(&.to_f.bohrs)
        raise "Invalid command lattice" unless values.size == 9
        bi, bj, bk = { {0, 1, 2}, {3, 4, 5}, {6, 7, 8} }.map do |idxs|
          Spatial::Vec3[*values[idxs]]
        end
        basis = Spatial::Mat3.basis bi, bj, bk
        Spatial::Parallelepiped.new(basis)
      end
    end
  end

  class Writer
    include FormatWriter(Structure)

    def initialize(
      @io : IO,
      @fractional : Bool = false,
      @wrap : Bool = false,
      @single_file : Bool = true,
      @sync_close : Bool = false
    )
    end

    def encode_entry(obj : Chem::Structure) : Nil
      io = @io
      close_file = false
      if io.is_a?(File) && !@single_file
        io = File.open Path[io.path].with_ext(".lattice"), "w"
        close_file = true
      end

      io.puts "lattice \\"
      obj.cell.basisvec.each_with_index do |vec, i|
        io.printf "    %21.15f%21.15f%21.15f",
          vec.x.to_bohrs,
          vec.y.to_bohrs,
          vec.z.to_bohrs
        io.puts " \\" if i < 2
      end
      io.puts

      io.close if close_file

      @io.print "coords-type "
      @io.puts @fractional ? "Lattice" : "Cartesian"
      obj.atoms.each do |atom|
        vec = atom.coords
        if @fractional
          format = "%22.16f"
          vec = obj.cell.fract vec
          vec = vec.wrap if @wrap
        else
          format = "%8.3f"
          vec = vec.map &.to_bohrs
          vec = obj.cell.wrap vec if @wrap
        end
        @io.printf "ion%4s#{format}#{format}#{format}%2d\n",
          atom.element.symbol,
          vec.x,
          vec.y,
          vec.z,
          atom.constraint.try(&.xyz?) ? 0 : 1
      end
    end
  end
end
