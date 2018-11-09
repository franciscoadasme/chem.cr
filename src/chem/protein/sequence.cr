module Chem::Protein
  struct Sequence
    @aminoacids = [] of Protein::AminoAcid

    def initialize(aminoacids : Array(Protein::AminoAcid))
      @aminoacids = aminoacids.dup
    end

    def self.build(&block : Array(Protein::AminoAcid) ->) : self
      aminoacids = [] of Protein::AminoAcid
      yield aminoacids
      new aminoacids
    end

    def to_s
      String.build do |builder|
        @aminoacids.each do |aa|
          builder << aa.letter
        end
      end
    end
  end
end
