module Chem::Protein
  struct AminoAcid
    getter name : String
    getter code : String
    getter letter : Char

    def initialize(@name : String, @code : String, @letter : Char)
    end

    def self.[](code : String) : self
      {% begin %}
        case code.upcase
        {% for constant in AminoAcids.constants %}
          when {{constant.stringify}}
            AminoAcids::{{constant}}
        {% end %}
        else
          AminoAcids::UNK
        end
      {% end %}
    end
  end
end
