struct Chem::Structure::Experiment
  enum Method
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
  getter method : Method = :x_ray_diffraction
  getter pdb_accession : String
  getter resolution : Float64?
  getter title : String

  def initialize(@title : String,
                 @method : Method,
                 @resolution : Float64?,
                 @pdb_accession : String,
                 @deposition_date : Time,
                 @doi : String?)
  end
end
