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
  end
end
