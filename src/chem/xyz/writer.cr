module Chem::XYZ
  @[IO::FileType(format: XYZ, ext: [:xyz])]
  class Writer < IO::Writer
    def initialize(@io : ::IO)
    end

    def <<(structure : Structure) : self
      @io << structure.size << '\n'
      @io << structure.title << '\n'
      structure.each_atom { |atom| self << atom }
      self
    end

    private def <<(atom : Atom) : Nil
      @io.printf "%-3s%15.5f%15.5f%15.5f\n", atom.element.symbol, atom.x, atom.y, atom.z
    end
  end
end
