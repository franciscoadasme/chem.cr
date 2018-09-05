require "./atom"

module Chem
  class Residue
    getter atoms : Array(Atom)
    getter index : Int32
    getter name : String
    getter number : Int32

    def initialize(@name, @number, @atoms)
      @index = @number - 1
    end
  end
end
