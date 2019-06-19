require "./stride/*"

module Chem::Protein::Stride
  def self.assign_secondary_structure(structure : Structure) : Nil
    Calculator.new(structure).assign
  end
end
