@[Chem::RegisterFormat(ext: %w(.poscar), names: %w(POSCAR* CONTCAR*), module_api: true)]
module Chem::VASP::Poscar
  # Returns the structure from *io*.
  #
  # Direct coordinates are always converted to Cartesian coordinates and both the unit cell vectors and atom positions are scaled by the scale factor.
  def self.read(io : IO, guess_bonds : Bool = false, guess_names : Bool = false) : Structure
    pull = PullParser.new(io)
    raise IO::EOFError.new if pull.eof?

    title = pull.line!.strip
    pull.consume_line
    scale_factor = pull.next_f
    pull.consume_line

    # read unit cell
    vi = Spatial::Vec3.new pull.next_f, pull.next_f, pull.next_f
    pull.consume_line
    vj = Spatial::Vec3.new pull.next_f, pull.next_f, pull.next_f
    pull.consume_line
    vk = Spatial::Vec3.new pull.next_f, pull.next_f, pull.next_f
    pull.consume_line
    cell = Spatial::Parallelepiped.new Spatial::Mat3.basis(vi, vj, vk) * scale_factor

    # read species
    uniq_elements = [] of Element
    while (str = pull.next_s?) && str[0].ascii_letter?
      ele = PeriodicTable[str]? || pull.error("Unknown element")
      uniq_elements << ele
    end
    pull.error("Missing atom species") if uniq_elements.empty?
    pull.consume_line

    # read atom count
    elements = [] of Element
    uniq_elements.map do |ele|
      if count = pull.next_i?
        count.times { elements << ele }
      else
        pull.error "Couldn't read number of atoms for #{ele.symbol}"
      end
    end
    pull.consume_line

    # read selective dynamics flag
    constrained = false
    if pull.consume_token.char.in?('s', 'S')
      constrained = true
      pull.consume_line
      pull.consume_token
    end

    # read coordinate system (cartesian or direct)
    fractional = false
    case pull.char
    when 'C', 'c', 'K', 'k' # cartesian
      fractional = false
    when 'D', 'd' # direct
      fractional = true
    else
      pull.error "Invalid coordinate system"
    end
    pull.consume_line

    Structure.build(
      guess_bonds: guess_bonds,
      guess_names: guess_names,
      source_file: (file = io).is_a?(File) ? file.path : nil,
      use_templates: false,
    ) do |builder|
      builder.title title
      builder.cell cell
      elements.each do |element|
        vec = Spatial::Vec3.new pull.next_f, pull.next_f, pull.next_f
        vec = fractional ? cell.cart(vec) : vec * scale_factor
        atom = builder.atom element, vec
        if constrained
          case {read_flag(pull), read_flag(pull), read_flag(pull)}
          when {false, true, true}   then atom.constraint = :x
          when {true, false, true}   then atom.constraint = :y
          when {true, true, false}   then atom.constraint = :z
          when {false, false, true}  then atom.constraint = :xy
          when {false, true, false}  then atom.constraint = :xz
          when {true, false, false}  then atom.constraint = :yz
          when {false, false, false} then atom.constraint = :xyz
          end
        end
        pull.consume_line
      end
    end
  end

  # :ditto:
  def self.read(io : Path | String, guess_bonds : Bool = false, guess_names : Bool = false) : Structure
    File.open(io) do |file|
      read(file, guess_bonds, guess_names)
    end
  end

  private def self.read_flag(pull : PullParser) : Bool
    case pull.consume_token.char
    when 'T' then true
    when 'F' then false
    else          pull.error "Invalid boolean flag (expected either T or F)"
    end
  end

  # Writes a structure to *io*. Raises `Spatial::NotPeriodicError` if the structure is not periodic.
  #
  # If given, *order* specifies the element order in the output, otherwise the order of the first occurrence of each element in the structure is used.
  # *order* can be an array of `Element` instances or element symbols (as strings) for convenience.
  #
  # Atom positions are written in direct (fractional) coordinates if *fractional* is true, Cartesian otherwise.
  # Additionally, atom positions may be wrapped into the unit cell during writing if *wrap* is true (original positions are not modified).
  #
  # ```
  # order = [Chem::PeriodicTable::O, Chem::PeriodicTable::Na, Chem::PeriodicTable::Cl]
  # Chem::VASP::Poscar.write(io, structure, order)
  # # or
  # Chem::VASP::Poscar.write(io, structure, order: %w(O Na Cl))
  # ```
  def self.write(
    io : IO,
    structure : Structure,
    order : Array(Element) | Array(String) | Nil = nil,
    fractional : Bool = false,
    wrap : Bool = false,
  ) : Nil
    raise Spatial::NotPeriodicError.new unless cell = structure.cell?

    atoms = structure.atoms
    coordinate_system = fractional ? "Direct" : "Cartesian"
    ele_tally = atoms.map(&.element).tally
    elements = ele_tally.keys
    if order
      order = order.map { |sym| PeriodicTable[sym] } if order.is_a?(Array(String))
      elements.sort_by! do |ele|
        order.index(ele).as(Int32?) ||
          raise ArgumentError.new "#{ele} not found in the specified order"
      end
    end
    has_constraints = atoms.any? &.constraint

    io.puts structure.title.gsub(/ *\n */, ' ')
    io.printf " %18.14f\n", 1.0
    cell.basisvec.each do |vec|
      io.printf " %22.16f%22.16f%22.16f\n", vec.x, vec.y, vec.z
    end
    elements.each { |ele| io.printf "%5s", ele.symbol.ljust(2) }
    io.puts
    elements.each { |ele| io.printf "%6d", ele_tally[ele] }
    io.puts
    io.puts "Selective dynamics" if has_constraints
    io.puts coordinate_system

    elements.each do |ele|
      atoms.each.select(ele).each do |atom|
        vec = atom.pos
        if fractional
          vec = cell.fract vec
          vec = vec.wrap if wrap
        elsif wrap
          vec = cell.wrap vec
        end

        io.printf "%22.16f%22.16f%22.16f", vec.x, vec.y, vec.z
        if has_constraints
          {% for axis in %w(x y z) %}
            io.printf "%4s", atom.constraint.try(&.includes?({{ ":#{axis}".id }})) ? 'F' : 'T'
          {% end %}
        end
        io.puts
      end
    end
  end

  # :ditto:
  def self.write(
    io : Path | String,
    structure : Structure,
    order : Array(Element) | Array(String) | Nil = nil,
    fractional : Bool = false,
    wrap : Bool = false,
  ) : Nil
    File.open(io, mode: "w") do |file|
      write file, structure, order, fractional, wrap
    end
  end
end
