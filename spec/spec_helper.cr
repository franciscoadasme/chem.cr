require "spec"
require "../src/chem"

alias Atom = Chem::Atom
alias AtomView = Chem::AtomView
alias Constraint = Chem::Constraint
alias Element = Chem::PeriodicTable::Element
alias PDB = Chem::PDB
alias PeriodicTable = Chem::PeriodicTable
alias Vector = Chem::Spatial::Vector

module Spec
  struct CloseExpectation
    def match(actual_value : Array(T)) forall T
      if @expected_value.size != actual_value.size
        raise ArgumentError.new "arrays have different sizes"
      end
      actual_value.zip(@expected_value).all? { |a, b| (a - b).abs <= @delta }
    end

    def match(actual_value : Chem::Spatial::Vector)
      [(actual_value.x - @expected_value.x).abs,
       (actual_value.y - @expected_value.y).abs,
       (actual_value.z - @expected_value.z).abs].all? do |value|
        value <= @delta
      end
    end
  end
end

module Chem::VASP::Poscar
  def self.write_and_read_back(system : System) : System
    io = ::IO::Memory.new
    Poscar.write io, system
    io.rewind
    other = Poscar.parse io
    io.close
    other
  end
end

def fake_residue_with_alternate_conformations
  sys = Chem::System.new
  sys << (chain = Chem::Chain.new 'A', sys)
  chain << (residue = Chem::Residue.new "SER", 1, chain)

  residue << Atom.new "N", 0, Vector.zero, residue
  residue << Atom.new "CA", 1, Vector.zero, residue
  residue << Atom.new "C", 2, Vector.zero, residue
  residue << Atom.new "O", 3, Vector.zero, residue
  residue << Atom.new "CB", 4, Vector[1, 0, 0], residue, 'A', occupancy: 0.65
  residue << Atom.new "CB", 5, Vector[2, 0, 0], residue, 'B', occupancy: 0.25
  residue << Atom.new "CB", 6, Vector[3, 0, 0], residue, 'C', occupancy: 0.1
  residue << Atom.new "OG", 7, Vector[1, 0, 0], residue, 'A', occupancy: 0.65
  residue << Atom.new "OG", 8, Vector[2, 0, 0], residue, 'B', occupancy: 0.35
  residue << Atom.new "OG", 9, Vector[3, 0, 0], residue, 'C', occupancy: 0.1
end

# TODO add SystemBuilder?
def fake_system(*, include_bonds = false)
  sys = Chem::System.new
  sys.title = "Asp-Phe Ser"
  chain = sys.make_chain identifier: 'A'
  residue = chain.make_residue name: "ASP", number: 1
  residue.make_atom name: "N", index: 0, coords: Vector[-2.186, 22.128, 79.139]
  residue.make_atom name: "CA", index: 1, coords: Vector[-0.955, 21.441, 78.711]
  residue.make_atom name: "C", index: 2, coords: Vector[-0.595, 21.849, 77.252]
  residue.make_atom name: "O", index: 3, coords: Vector[-1.461, 21.781, 76.374]
  residue.make_atom name: "CB", index: 4, coords: Vector[-1.316, 19.953, 79.003]
  residue.make_atom name: "CG", index: 5, coords: Vector[-0.895, 18.952, 77.936]
  residue.make_atom name: "OD1", index: 6, coords: Vector[-1.281, 17.738, 78.086]
  residue.make_atom name: "OD2", index: 7, coords: Vector[-0.209, 19.223, 76.945], charge: -1

  residue = chain.make_residue name: "PHE", number: 2
  residue.make_atom name: "N", index: 8, coords: Vector[0.647, 22.313, 76.991]
  residue.make_atom name: "CA", index: 9, coords: Vector[1.092, 22.731, 75.639]
  residue.make_atom name: "C", index: 10, coords: Vector[1.006, 21.699, 74.529]
  residue.make_atom name: "O", index: 11, coords: Vector[0.990, 22.038, 73.319]
  residue.make_atom name: "CB", index: 12, coords: Vector[2.618, 23.255, 75.696]
  residue.make_atom name: "CG", index: 13, coords: Vector[2.643, 24.713, 75.877]
  residue.make_atom name: "CD1", index: 14, coords: Vector[1.790, 25.237, 76.833]
  residue.make_atom name: "CD2", index: 15, coords: Vector[3.242, 25.569, 74.992]
  residue.make_atom name: "CE1", index: 16, coords: Vector[1.639, 26.577, 76.996]
  residue.make_atom name: "CE2", index: 17, coords: Vector[3.100, 26.930, 75.157]
  residue.make_atom name: "CZ", index: 18, coords: Vector[2.331, 27.435, 76.167]

  chain = sys.make_chain identifier: 'B'
  residue = chain.make_residue name: "SER", number: 1
  residue.make_atom name: "N", index: 19, coords: Vector[7.186, 2.582, 8.445]
  residue.make_atom name: "CA", index: 20, coords: Vector[6.500, 1.584, 7.565]
  residue.make_atom name: "C", index: 21, coords: Vector[5.382, 2.313, 6.773]
  residue.make_atom name: "O", index: 22, coords: Vector[5.213, 2.016, 5.557]
  residue.make_atom name: "CB", index: 23, coords: Vector[5.908, 0.462, 8.400]
  residue.make_atom name: "OG", index: 24, coords: Vector[6.990, -0.272, 9.012]

  Chem::Topology.guess_topology of: sys if include_bonds

  sys
end
