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

    def self.[](code : Char) : self
      self[code]? || raise "Unknown secondary structure code: #{code}"
    end

    def self.[]?(code : Char) : self?
      case code.upcase
      when 'H'      then HelixAlpha
      when 'G'      then Helix3_10
      when 'I'      then HelixPi
      when 'E'      then BetaStrand
      when 'B'      then BetaBridge
      when 'T'      then Turn
      when '0', 'C' then None
      else               nil
      end
    end

    def beta? : Bool
      beta_strand?
    end

    def coil? : Bool
      bend? || none? || turn?
    end

    # Returns the one-letter DSSP secondary structure code.
    #
    # If *simplified* is `true`, returns the simplified code (see below) instead.
    #
    # The DSSP assignment codes are:
    #
    # - `'H'` : α-helix (4-turn)
    # - `'B'` : β-bridge
    # - `'E'` : β-strand
    # - `'G'` : 3₁₀-helix (3-turn)
    # - `'I'` : π-helix (5-turn)
    # - `'T'` : Turn
    # - `'S'` : Bend
    # - `'0'` : None (loops and irregular elements)
    #
    # The simplified DSSP codes are:
    #
    # - `'H'` : Helix. Either of the `'H'`, `'G'`, or `'I'` codes
    # - `'E'` : Strand. Either of the `'E'`, or `'B'` codes
    # - `'0'` : Coil. Either of the `'T'`, `'S'` or `'0'` codes
    def dssp(*, simplified : Bool = false) : Char
      if simplified
        case self
        when .helix_3_10?, .helix_alpha?, .helix_pi? then 'H'
        when .beta_bridge?, .beta_strand?            then 'E'
        else                                              '0'
        end
      else
        case self
        when .bend?        then 'S'
        when .beta_bridge? then 'B'
        when .beta_strand? then 'E'
        when .helix_3_10?  then 'G'
        when .helix_alpha? then 'H'
        when .helix_pi?    then 'I'
        when .turn?        then 'T'
        else                    '0'
        end
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
