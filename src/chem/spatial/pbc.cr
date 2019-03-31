module Chem::Spatial::PBC
  extend self

  def wrap(atoms : AtomCollection, lattice : Lattice)
    wrap atoms, lattice, lattice.center
  end

  def wrap(atoms : AtomCollection, lattice : Lattice, center : Spatial::Vector)
    if lattice.cuboid?
      vecs = {lattice.a, lattice.b, lattice.c}
      normed_vecs = vecs.map &.normalize
      atoms.each_atom do |atom|
        d = atom.coords - center
        {% for i in 0..2 %}
          fd = d.dot(normed_vecs[{{i}}]) / vecs[{{i}}].size
          atom.coords += -fd.round * vecs[{{i}}] if fd.abs > 0.5
        {% end %}
      end
    else
      basis = Linalg::Basis.new lattice.a, lattice.b, lattice.c
      transform = Linalg::Basis.standard.transform to: basis
      atoms.transform by: transform
      wrap atoms, Lattice.new(V.x, V.y, V.z), (transform * center)
      atoms.transform by: transform.inv
    end
  end
end
