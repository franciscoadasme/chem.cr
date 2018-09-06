module Chem::Protein
  struct Sequence
    @aminoacids = [] of Protein::AminoAcid

    def to_s
      String.build do |builder|
        @aminoacids.each do |aa|
          builder << aa.letter
        end
      end
    end
  end
end
