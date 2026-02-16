@[Chem::RegisterFormat(ext: %w(.ionpos .lattice), module_api: true)]
module Chem::JDFTx
  # Reads the structure from *io*.
  #
  # If *io* is a file, a sibling `.lattice` file is read for the unit cell.
  def self.read(io : IO, guess_bonds : Bool = false, guess_names : Bool = false) : Structure
    fractional = false
    lattice_scale = {1.0, 1.0, 1.0}

    struc = Structure.build(
      guess_bonds: guess_bonds,
      guess_names: guess_names,
      source_file: (file = io).is_a?(File) ? file.path : nil,
      use_templates: false,
    ) do |builder|
      # FIXME: use pull parser!
      remove_multiple_line_commands(io.gets_to_end).each_line do |line|
        tokens = line.split
        case tokens.first?.try(&.downcase)
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
          builder.cell parse_cell(line)
        end
      end

      if file = io.as?(File)
        path = Path[file.path]
        path = path.sibling "#{path.stem}.lattice"
        if File.exists?(path)
          builder.cell parse_cell remove_multiple_line_commands(File.read(path))
        end
      end
    end

    struc.cell = struc.cell.try &.scale(*lattice_scale)
    if fractional
      raise "Missing command lattice" unless struc.cell
      struc.pos.to_cart!
    end

    struc
  end

  # :ditto:
  def self.read(path : Path | String, guess_bonds : Bool = false, guess_names : Bool = false) : Structure
    File.open(path) do |file|
      read(file, guess_bonds, guess_names)
    end
  end

  # Writes a structure to *io*.
  #
  # Atom positions are written in fractional coordinates if *fractional* is true, Cartesian otherwise.
  # Additionally, atom positions may be wrapped into the unit cell during writing if *wrap* is true (original positions are not modified).
  # Raises `Spatial::NotPeriodicError` if *fractional* is true and the structure is not periodic.
  #
  # Unit cell and atoms are written to the same file if *single_file* is true, otherwise the lattice is written to a sibling `.lattice` file.
  def self.write(
    io : IO,
    structure : Structure,
    fractional : Bool = false,
    wrap : Bool = false,
    single_file : Bool = true,
  ) : Nil
    inner_io = io
    close_file = false
    if io.is_a?(File) && !single_file
      inner_io = File.open Path[io.path].with_ext(".lattice"), "w"
      close_file = true
    end

    inner_io.puts "lattice \\"
    structure.cell.basisvec.each_with_index do |vec, i|
      inner_io.printf "    %21.15f%21.15f%21.15f",
        vec.x.to_bohrs,
        vec.y.to_bohrs,
        vec.z.to_bohrs
      inner_io.puts " \\" if i < 2
    end
    inner_io.puts

    inner_io.close if close_file

    io.print "coords-type "
    io.puts fractional ? "Lattice" : "Cartesian"
    structure.atoms.each do |atom|
      vec = atom.pos
      if fractional
        format = "%22.16f"
        vec = structure.cell.fract vec
        vec = vec.wrap if wrap
      else
        format = "%8.3f"
        vec = vec.map &.to_bohrs
        vec = structure.cell.wrap vec if wrap
      end
      io.printf "ion%4s#{format}#{format}#{format}%2d\n",
        atom.element.symbol,
        vec.x,
        vec.y,
        vec.z,
        atom.constraint.try(&.xyz?) ? 0 : 1
    end
  end

  # :ditto:
  def self.write(
    path : Path | String,
    structure : Structure,
    fractional : Bool = false,
    wrap : Bool = false,
    single_file : Bool = true,
  ) : Nil
    File.open(path, mode: "w") do |file|
      write(file, structure, fractional: fractional, wrap: wrap, single_file: single_file)
    end
  end
end

private def parse_cell(line : String) : Chem::Spatial::Parallelepiped
  tokens = line.split
  case tokens[1].downcase
  when "monoclinic"
    a, _, c = tokens[1..3].map(&.to_f.bohrs)
    beta = tokens[4].to_f
    Chem::Spatial::Parallelepiped.monoclinic(a, c, beta)
  when "triclinic"
    lengths = {1, 2, 3}.map { |i| tokens[i].to_f.bohrs }
    angles = {4, 5, 6}.map { |i| tokens[i].to_f }
    Chem::Spatial::Parallelepiped.new(lengths, angles)
  when "orthorhombic"
    a, b, c = tokens[1..3].map(&.to_f.bohrs)
    Chem::Spatial::Parallelepiped.orthorhombic(a, b, c)
  when "tetragonal"
    a, c = tokens[1..2].map(&.to_f.bohrs)
    Chem::Spatial::Parallelepiped.tetragonal(a, c)
  when "hexagonal"
    a, c = tokens[1..2].map(&.to_f.bohrs)
    Chem::Spatial::Parallelepiped.hexagonal(a, c)
  when "rhombohedral"
    a = tokens[1].to_f.bohrs
    alpha = tokens[2].to_f
    Chem::Spatial::Parallelepiped.rhombohedral(a, alpha)
  when "cubic"
    size = tokens[1].to_f.bohrs
    Chem::Spatial::Parallelepiped.cubic(size)
  else
    values = tokens[1..9].map(&.to_f.bohrs)
    raise "Invalid command lattice" unless values.size == 9
    bi, bj, bk = { {0, 1, 2}, {3, 4, 5}, {6, 7, 8} }.map do |idxs|
      Chem::Spatial::Vec3[*values[idxs]]
    end
    basis = Chem::Spatial::Mat3.basis bi, bj, bk
    Chem::Spatial::Parallelepiped.new(basis)
  end
end

private def remove_multiple_line_commands(content : String) : String
  content.gsub(/\s*\\\s*\n\s*/, ' ')
end
