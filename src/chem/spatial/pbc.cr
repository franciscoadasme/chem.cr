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

    # Check if atoms are wrapped, otherwise use offset to bring atoms to
    # primary cell
    bounds = atoms.coords.bounds
    wrapped = lattice.bounds.includes?(bounds)
    offset = wrapped ? Vector.zero : (lattice.bounds.center - bounds.center)
    offset = offset.to_fractional(lattice)

    extents = StaticArray(Range(Float64, Float64), 3).new 0.0..0.0
    padding = (0..2).map { |i| (radius / lattice.size[i]).clamp(..0.5) }

    atoms.each_atom do |atom|
      vec = atom.coords.to_fractional(lattice) + offset
      img_sense = vec.map { |ele| ele < 0.5 ? 1 : -1 }
      3.times do |i|
        x, px = vec[i], padding[i]
        extents[i] = case x
                     when .<(0) then (x - px)..(x + 1 + px)
                     when .>(1) then (1 - x - px)..(x + px)
                     else            -px..(1 + px)
                     end
      end

      ADJACENT_IMAGE_IDXS.each do |img_idx|
        img_vec = vec + img_sense * img_idx
        if 3.times.all? { |i| extents[i].includes? img_vec[i] }
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
    return if moved_atoms.includes? atom

    atom.coords -= (atom.coords - center).round
    moved_atoms << atom

    atom.each_bonded_atom do |other|
      assemble_fragment other, atom.coords, moved_atoms
    end
  end
end
