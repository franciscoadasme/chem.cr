module Chem::Protein
  struct Sequence
    @aminoacids : Array(AminoAcid)

    def to_s
      String.build do |builder|
        @aminoacids.each do |aa|
          builder << aa.letter
        end
      end
    end
  end
end
