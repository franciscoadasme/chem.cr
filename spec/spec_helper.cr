require "spec"
require "../src/chem"

alias Atom = Chem::Atom
alias AtomView = Chem::AtomView
alias Constraint = Chem::Constraint
alias Element = Chem::PeriodicTable::Element
alias Elements = Chem::PeriodicTable::Elements
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
