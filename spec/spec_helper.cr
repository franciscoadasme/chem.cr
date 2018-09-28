require "spec"
require "../src/chem"

alias Atom = Chem::Atom
alias AtomView = Chem::AtomView
alias Constraint = Chem::Constraint
alias Element = Chem::PeriodicTable::Element
alias PDB = Chem::PDB
alias PeriodicTable = Chem::PeriodicTable
alias Vector = Chem::Geometry::Vector

module Spec
  struct CloseExpectation
    def match(actual_value : Array(T)) forall T
      if @expected_value.size != actual_value.size
        raise ArgumentError.new "arrays have different sizes"
      end
      actual_value.zip(@expected_value).all? { |a, b| (a - b).abs <= @delta }
    end

    def match(actual_value : Chem::Geometry::Vector)
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

# TODO add SystemBuilder?
def fake_system
  sys = Chem::System.new
  sys.title = "Glu-Phe Ser"
  chain = sys.make_chain identifier: 'A'
  residue = chain.make_residue name: "GLU", number: 1
  residue.make_atom name: "N", index: 0, coords: Vector[-0.626, -1.518, 0.865]
  residue.make_atom name: "CA", index: 1, coords: Vector[-0.370, -0.510, -0.145]
  residue.make_atom name: "C", index: 2, coords: Vector[0.945, -0.821, -0.873]
  residue.make_atom name: "O", index: 3, coords: Vector[1.624, -1.805, -0.581]
  residue.make_atom name: "CB", index: 4, coords: Vector[-0.368, 0.895, 0.480]
  residue.make_atom name: "CG", index: 5, coords: Vector[-0.108, 2.074, -0.471]
  residue.make_atom name: "CD", index: 6, coords: Vector[-0.108, 3.463, 0.160]
  residue.make_atom name: "OE1", index: 7, coords: Vector[0.979, 3.908, 0.591]
  residue.make_atom name: "OE2", index: 8, coords: Vector[-1.204, 4.061, 0.195], charge: -1

  residue = chain.make_residue name: "PHE", number: 2
  residue.make_atom name: "N", index: 9, coords: Vector[5.259, 5.498, 6.005]
  residue.make_atom name: "CA", index: 10, coords: Vector[5.929, 6.358, 5.055]
  residue.make_atom name: "C", index: 11, coords: Vector[6.304, 5.578, 3.799]
  residue.make_atom name: "O", index: 12, coords: Vector[6.136, 6.072, 2.653]
  residue.make_atom name: "CB", index: 13, coords: Vector[7.183, 6.994, 5.754]
  residue.make_atom name: "CG", index: 14, coords: Vector[7.884, 8.006, 4.883]
  residue.make_atom name: "CD1", index: 15, coords: Vector[8.906, 7.586, 4.027]
  residue.make_atom name: "CD2", index: 16, coords: Vector[7.532, 9.373, 4.983]
  residue.make_atom name: "CE1", index: 17, coords: Vector[9.560, 8.539, 3.194]
  residue.make_atom name: "CE2", index: 18, coords: Vector[8.176, 10.281, 4.145]
  residue.make_atom name: "CZ", index: 19, coords: Vector[9.141, 9.845, 3.292]

  chain = sys.make_chain identifier: 'B'
  residue = chain.make_residue name: "SER", number: 1
  residue.make_atom name: "N", index: 20, coords: Vector[7.186, 2.582, 8.445]
  residue.make_atom name: "CA", index: 21, coords: Vector[6.500, 1.584, 7.565]
  residue.make_atom name: "C", index: 22, coords: Vector[5.382, 2.313, 6.773]
  residue.make_atom name: "O", index: 23, coords: Vector[5.213, 2.016, 5.557]
  residue.make_atom name: "CB", index: 24, coords: Vector[5.908, 0.462, 8.400]
  residue.make_atom name: "OG", index: 25, coords: Vector[6.990, -0.272, 9.012]

  sys
end
