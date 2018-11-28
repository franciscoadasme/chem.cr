module Chem::Protein
  enum SecondaryStructure
    HelixAlpha
    Helix3_10
    HelixPi
    BetaStrand
    BetaBridge
    Turn
    Bend
    None

    def beta? : Bool
      beta_strand?
    end

    def coil? : Bool
      bend? || none? || turn?
    end

    def dssp : Char
      case self
      when .bend?        then 'S'
      when .beta_bridge? then 'B'
      when .beta_strand? then 'E'
      when .helix_3_10?  then 'G'
      when .helix_alpha? then 'H'
      when .helix_pi?    then 'I'
      when .none?        then '0'
      when .turn?        then 'T'
      else                    '0'
      end
    end

    def helix? : Bool
      helix_alpha? || helix_3_10? || helix_pi?
    end

    def helix_3_10? : Bool
      helix3_10?
    end
  end
end
