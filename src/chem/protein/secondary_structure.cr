module Chem::Protein
  enum SecondaryStructure
    HelixRightHandedAlpha =   1
    HelixRightHandedOmega =   2
    HelixRightHandedPi    =   3
    HelixRightHandedGamma =   4
    HelixRightHanded310   =   5
    HelixLeftHandedAlpha  =   6
    HelixLeftHandedGamma  =   7
    HelixLeftHandedOmega  =   8
    HelixRibbon27         =   9
    HelixPolyproline      =  10
    BetaAntiparallel      =  99
    BetaFirst             = 100
    BetaParallel          = 101
    Turn                  = 200
    Bend                  = 300
    None                  =   0

    def dssp : Char
      case self
      when .bend?
        'S'
      when .beta_antiparallel?, .beta_first?
        'B'
      when .beta_parallel?
        'E'
      when .helix_right_handed_310?
        'G'
      when .helix_right_handed_alpha?, .helix_left_handed_alpha?
        'H'
      when .helix_right_handed_pi?
        'I'
      when .none?
        '0'
      when .turn?
        'T'
      else
        '0'
      end
    end

    def helix_right_handed_310? : Bool
      helix_right_handed310?
    end
  end
end
