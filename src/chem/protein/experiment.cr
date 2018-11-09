module Chem::Protein
  struct Experiment
    enum Kind
      ElectronCrystallography
      ElectronMicroscopy
      FiberDiffraction
      NeutronDiffraction
      SolidStateNMR
      SolutionNMR
      SolutionScattering
      XRayDiffraction
    end

    getter deposition_date : Time
    getter doi : String?
    getter kind : Kind = :x_ray_diffraction
    getter pdb_accession : String
    getter resolution : Float64?
    getter title : String

    def initialize(@title : String,
                   @kind : Kind,
                   @resolution : Float64?,
                   @pdb_accession : String,
                   @deposition_date : Time,
                   @doi : String?)
    end
  end
end
