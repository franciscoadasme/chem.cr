module Chem::Spatial::PBC
  extend self

  ADJACENT_IMAGE_IDXS = [{1, 0, 0}, {0, 1, 0}, {0, 0, 1}, {1, 1, 0}, {1, 0, 1},
                         {0, 1, 1}, {1, 1, 1}]

  def adjacent_images(*args, **options) : Array(Tuple(Atom, Vector))
    ary = [] of Tuple(Atom, Vector)
    each_adjacent_image(*args, **options) do |atom, coords|
      ary << {atom, coords}
    end
    ary
  end

  def each_adjacent_image(structure : Structure, &block : Atom, Vector ->)
    raise NotPeriodicError.new unless lattice = structure.lattice
    each_adjacent_image structure, lattice, &block
  end

  def each_adjacent_image(atoms : AtomCollection,
                          lattice : Lattice,
                          &block : Atom, Vector ->)
    offset = (lattice.bounds.center - atoms.coords.center).to_fractional lattice
    atoms.each_atom do |atom|
      fcoords = atom.coords.to_fractional lattice                     # convert to fractional coords
      w_fcoords = fcoords - fcoords.floor                             # wrap to primary unit cell
      ax_offset = (fcoords + offset).map { |ele| ele < 0.5 ? 1 : -1 } # compute offset per axis

      ADJACENT_IMAGE_IDXS.each do |img_idx|
        yield atom, (fcoords + ax_offset * img_idx).to_cartesian(lattice)
      end
    end
  end

  def each_adjacent_image(structure : Structure,
                          radius : Number,
                          &block : Atom, Vector ->)
    raise NotPeriodicError.new unless lattice = structure.lattice
    each_adjacent_image structure, lattice, radius, &block
  end

  def each_adjacent_image(atoms : AtomCollection,
                          lattice : Lattice,
                          radius : Number,
                          &block : Atom, Vector ->)
    raise Error.new "Radius cannot be negative" if radius < 0

    offset = offset_to_primary_unit_cell atoms, lattice
    paddings = cell_paddings lattice, radius

    atoms.each_atom do |atom|
      vec = atom.coords.to_fractional(lattice) + offset
      extents = padded_cell_extents vec, paddings
      img_sense = vec.map { |ele| ele < 0.5 ? 1 : -1 }

      ADJACENT_IMAGE_IDXS.each do |img_idx|
        img_vec = vec + img_sense * img_idx
        if (0..2).all? { |i| img_vec[i].in? extents[i] }
          yield atom, (img_vec - offset).to_cartesian(lattice)
        end
      end
    end
  end

  def unwrap(atoms : AtomCollection, lattice : Lattice) : Nil
    atoms.coords.to_fractional!
    moved_atoms = Set(Atom).new
    atoms.each_fragment do |fragment|
      assemble_fragment fragment[0], fragment[0].coords, moved_atoms
      fragment.coords.translate! by: -fragment.coords.center.floor
      moved_atoms.clear
    end
    atoms.coords.to_cartesian!
  end

  private def assemble_fragment(atom, center, moved_atoms) : Nil
    return if atom.in?(moved_atoms)

    atom.coords -= (atom.coords - center).round
    moved_atoms << atom

    atom.each_bonded_atom do |other|
      assemble_fragment other, atom.coords, moved_atoms
    end
  end

  # Returns the padding along each cell vector as fractional numbers.
  private def cell_paddings(lattice : Lattice,
                            radius : Number) : StaticArray(Float64, 3)
    StaticArray(Float64, 3).new do |i|
      (radius / lattice.size[i]).clamp(..0.5)
    end
  end

  # Returns offset vector to bring atoms to the primary unit cell unless
  # atoms are wrapped, otherwise returns a zero vector.
  private def offset_to_primary_unit_cell(atoms : AtomCollection,
                                          lattice : Lattice) : Vector
    bounds = atoms.coords.bounds
    wrapped = lattice.bounds.includes?(bounds)
    offset = wrapped ? Vector.zero : (lattice.bounds.center - bounds.center)
    offset.to_fractional(lattice)
  end

  # Returns padded primary unit cell extents. If *vec* is outside the
  # primary unit cell, the extents are shifted so that *vec* is at the
  # edges.
  private def padded_cell_extents(
    vec : Vector,
    paddings : StaticArray(Float64, 3)
  ) : StaticArray(Range(Float64, Float64), 3)
    StaticArray(Range(Float64, Float64), 3).new do |i|
      x, px = vec[i], paddings[i]
      case x
      when .<(0) then (x - px)..(x + 1 + px)
      when .>(1) then (1 - x - px)..(x + px)
      else            -px..(1 + px)
      end
    end
  end
end
