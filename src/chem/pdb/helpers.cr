require "../protein"

module Chem::PDB
  private record SecondaryStructureSegment,
    chain : Char,
    kind : Protein::SecondaryStructure,
    range : Range(Int32, Int32)

  private class ExperimentBuilder
    setter deposition_date : Time?
    setter doi : String?
    setter kind = Protein::Experiment::Kind::XRayDiffraction
    setter pdb_accession = ""
    setter resolution : Float64?
    setter title = ""

    def build? : Protein::Experiment?
      return nil unless deposition_date = @deposition_date
      return nil if @pdb_accession.blank?
      return nil if @title.blank?
      Protein::Experiment.new @title, @kind, @resolution, @pdb_accession,
        deposition_date, @doi
    end
  end
end
