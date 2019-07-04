module Chem::XYZ
  @[IO::FileType(format: XYZ, ext: [:xyz])]
  class Builder < IO::Builder
    setter atoms = 0
    setter title = ""

    def initialize(@io : ::IO)
    end

    def object_header : Nil
      number @atoms
      newline
      string @title
      newline
    end
  end
end
