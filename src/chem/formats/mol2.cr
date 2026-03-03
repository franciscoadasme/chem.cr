@[Chem::RegisterFormat(ext: %w(.mol2))]
module Chem::Mol2
  # Yields each structure in *io*.
  def self.each(io : IO, & : Structure ->) : Nil
    loop do
      begin
        yield read(io)
      rescue IO::EOFError
        break
      end
    end
  end

  # :ditto:
  def self.each(path : Path | String, & : Structure ->) : Nil
    File.open(path) do |file|
      each(file) do |struc|
        yield struc
      end
    end
  end

  # Returns the first structure from *io*.
  # Use `read_all` or `each` for multiple.
  def self.read(io : IO) : Structure
    pull = PullParser.new(io)

    pull.each_line do
      break if (pull.str? || pull.next_s?) == "@<TRIPOS>MOLECULE"
    end
    pull.consume_line
    raise IO::EOFError.new if pull.eof?

    title = pull.line!.strip
    pull.consume_line
    n_atoms = pull.next_i
    n_bonds = pull.next_i
    pull.consume_line
    pull.consume_line
    include_charges = pull.next_s != "NO_CHARGES"
    pull.consume_line

    struc = Structure.build(
      guess_bonds: false,
      guess_names: false,
      source_file: (file = pull.io).is_a?(File) ? file.path : nil,
      use_templates: false,
    ) do |builder|
      builder.title title
      pull.each_line do
        case pull.str? || pull.next_s?
        when "@<TRIPOS>ATOM"
          n_atoms.times do
            pull.consume_line
            number = pull.next_i
            name = pull.next_s
            pos = Spatial::Vec3[pull.next_f, pull.next_f, pull.next_f]
            atom_t = pull.next_s
            symbol = atom_t[...atom_t.index('.')] # ignore sybyl type
            element = PeriodicTable[symbol]? || pull.error("Unknown element")
            unless pull.consume_token.eol?
              resid = pull.int
              resname = pull.next_s
              # TODO: respect name or truncate at 4 characters?
              builder.residue resname[..2], resid
              chg = pull.next_f if include_charges
            end
            builder.atom name, pos, element: element, partial_charge: (chg || 0.0)
          end
        when "@<TRIPOS>BOND"
          n_bonds.times do
            pull.consume_line
            pull.consume_token # skip bond index
            i = pull.next_i
            j = pull.next_i
            case bond_t = pull.next_s
            when "1", "2", "3"
              builder.bond i, j, BondOrder.from_value(bond_t.to_i)
            when "ar"
              builder.bond i, j, aromatic: true
            when "am", "du"
              builder.bond i, j
            end
          end
        when "@<TRIPOS>CRYSIN"
          pull.consume_line
          x = pull.next_f
          pull.error "Invalid size" unless x > 0
          y = pull.next_f
          pull.error "Invalid size" unless y > 0
          z = pull.next_f
          pull.error "Invalid size" unless z > 0
          alpha = pull.next_f
          pull.error "Invalid angle" unless 0 < alpha <= 180
          beta = pull.next_f
          pull.error "Invalid angle" unless 0 < beta <= 180
          gamma = pull.next_f
          pull.error "Invalid angle" unless 0 < gamma <= 180
          builder.cell Spatial::Parallelepiped.new({x, y, z}, {alpha, beta, gamma})
        when "@<TRIPOS>MOLECULE"
          # FIXME: hack such that the next call to read can start at this line
          if line = pull.line
            io.pos -= line.bytesize + 1
          end
          break
        end
      end
    end
    struc.guess_formal_charges
    struc
  end

  # :ditto:
  def self.read(path : Path | String) : Structure
    File.open(path) do |file|
      read(file)
    end
  end

  # Returns all structures in *io*.
  def self.read_all(io : IO) : Array(Structure)
    ary = [] of Structure
    each(io) do |struc|
      ary << struc
    end
    ary
  end

  # :ditto:
  def self.read_all(path : Path | String) : Array(Structure)
    File.open(path) do |file|
      read_all(file)
    end
  end

  # Writes one or more structures or groups of atoms to *io*.
  def self.write(io : IO, obj : AtomView | Structure) : Nil
    raise Error.new("Structure has no bonds") if obj.bonds.empty?

    atoms = obj.is_a?(AtomView) ? obj : obj.atoms
    atom_table = atoms.each.with_index(offset: 1).to_h
    res_table = obj.residues.each.with_index(offset: 1).to_h

    write_section(io, "molecule") do
      io.puts obj.is_a?(Structure) ? obj.title.gsub(/ *\n */, ' ') : ""
      io.printf "%5d%5d%4d\n", atoms.size, obj.bonds.size, obj.residues.size
      io.puts "UNKNOWN"
      io.puts "USER_CHARGES"
    end
    write_section(io, "atom") do
      atoms.each do |atom|
        io.printf "%5d %-4s%10.4f%10.4f%10.4f %-4s%4d %3s%-4d%8.4f\n",
          atom_table[atom],
          atom.name,
          atom.x, atom.y, atom.z,
          atom.element.symbol,
          res_table[atom.residue],
          atom.residue.name,
          atom.residue.number,
          atom.partial_charge
      end
    end
    write_section(io, "bond") do
      obj.bonds.each_with_index do |bond, i|
        io.printf "%5d%5d%5d%2d\n",
          i + 1,
          atom_table[bond.atoms[0]],
          atom_table[bond.atoms[1]],
          bond.order
      end
    end
    write_section(io, "substructure") do
      obj.residues.each do |residue|
        root_atom = residue.protein? ? residue.dig("CA") : residue.atoms[0]
        io.printf "%4d %-8s %5d %-8s %1s %1s %3s\n",
          res_table[residue],
          "#{residue.name[..2]}#{residue.number}",
          atom_table[root_atom],
          "RESIDUE",
          residue.protein? ? 1 : '*',
          residue.chain.id,
          residue.name[..2]
      end
    end

    if (struc = obj.as?(Structure)) && (cell = struc.cell?)
      write_section(io, "crysin") do
        a, b, c = cell.size
        alpha, beta, gamma = cell.angles
        io.printf "%.3f %.3f %.3f %.2f %.2f %.2f 1 1\n", a, b, c, alpha, beta, gamma
      end
    end
  end

  # :ditto:
  def self.write(path : Path | String, obj : Structure | AtomView) : Nil
    File.open(path, "w") do |file|
      write(file, obj)
    end
  end

  # :ditto:
  def self.write(io : IO, objs : Enumerable(Structure)) : Nil
    objs.each do |struc|
      write(io, struc)
    end
  end

  # :ditto:
  def self.write(path : Path | String, objs : Enumerable(Structure)) : Nil
    File.open(path, "w") do |file|
      write(file, objs)
    end
  end

  private def self.write_section(io : IO, name : String, & : ->) : Nil
    io << "@<TRIPOS>" << name.upcase << '\n'
    yield
    io.puts
  end
end
