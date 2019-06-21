require "./stride/*"

module Chem::Protein::Stride
  def self.assign(structure : Structure) : Nil
    Calculator.new(structure).assign
  end

  def self.calculate(structure : Structure) : Hash(Residue, SecondaryStructure)
    Calculator.new(structure).calculate
  end
end
