module Chem::Protein
  enum SecondaryStructure
    Bend
    BetaBridge
    BetaStrand
    LeftHandedHelix2_7
    LeftHandedHelix3_10
    LeftHandedHelixAlpha
    LeftHandedHelixPi
    None
    Polyproline
    RightHandedHelix2_7
    RightHandedHelix3_10
    RightHandedHelixAlpha
    RightHandedHelixPi
    Turn

    # Returns the secondary structure by one-letter code.
    #
    # Raises IndexError if `code` is invalid. See `#code` for a list of
    # codes.
    #
    # ```
    # SecondaryStructure['H'] # => SecondaryStructure::RightHandedHelixAlpha
    # SecondaryStructure['h'] # => SecondaryStructure::LeftHandedHelixAlpha
    # SecondaryStructure['E'] # => SecondaryStructure::BetaStrand
    # SecondaryStructure['e'] # => SecondaryStructure::BetaStrand
    # SecondaryStructure['X'] # raises IndexError
    # ```
    def self.[](code : Char) : self
      self[code]? || raise IndexError.new("Invalid secondary structure code: #{code}")
    end

    # Returns the secondary structure by one-letter code.
    #
    # Returns `nil` if `code` is invalid. See `#code` for a list of
    # codes.
    #
    # ```
    # SecondaryStructure['H']? # => SecondaryStructure::RightHandedHelixAlpha
    # SecondaryStructure['h']? # => SecondaryStructure::LeftHandedHelixAlpha
    # SecondaryStructure['E']? # => SecondaryStructure::BetaStrand
    # SecondaryStructure['e']? # => SecondaryStructure::BetaStrand
    # SecondaryStructure['X']? # => nil
    # ```
    def self.[]?(code : Char) : self?
      case code
      when 'S', 's'      then Bend
      when 'B', 'b'      then BetaBridge
      when 'E', 'e'      then BetaStrand
      when 'f'           then LeftHandedHelix2_7
      when 'g'           then LeftHandedHelix3_10
      when 'h'           then LeftHandedHelixAlpha
      when 'i'           then LeftHandedHelixPi
      when '0', 'C', 'c' then None
      when 'P', 'p'      then Polyproline
      when 'F'           then RightHandedHelix2_7
      when 'G'           then RightHandedHelix3_10
      when 'H'           then RightHandedHelixAlpha
      when 'I'           then RightHandedHelixPi
      when 'T', 't'      then Turn
      else                    nil
      end
    end

    # Returns one-letter secondary structure code.
    #
    # Codes are a superset of those defined by DSSP:
    #
    # - `'I'` : Right-handed π-helix (5-turn)
    # - `'H'` : Right-handed α-helix (4-turn)
    # - `'G'` : Right-handed 3₁₀-helix (3-turn)
    # - `'F'` : Right-handed 2.2₇ (2-turn)
    # - `'i'` : Left-handed π-helix (5-turn)
    # - `'h'` : Left-handed α-helix (4-turn)
    # - `'g'` : Left-handed 3₁₀-helix (3-turn)
    # - `'f'` : Left-handed 2.2₇ (2-turn)
    # - `'P'` : Polyproline
    # - `'E'` : β-strand
    # - `'B'` : β-bridge
    # - `'T'` : Turn
    # - `'S'` : Bend
    # - `'0'` : None
    def code : Char
      case self
      when .bend?                     then 'S'
      when .beta_bridge?              then 'B'
      when .beta_strand?              then 'E'
      when .left_handed_helix2_7?     then 'f'
      when .left_handed_helix3_10?    then 'g'
      when .left_handed_helix_alpha?  then 'h'
      when .left_handed_helix_pi?     then 'i'
      when .none?                     then '0'
      when .polyproline?              then 'P'
      when .right_handed_helix2_7?    then 'F'
      when .right_handed_helix3_10?   then 'G'
      when .right_handed_helix_alpha? then 'H'
      when .right_handed_helix_pi?    then 'I'
      when .turn?                     then 'T'
      else                                 raise "BUG: unreachable"
      end
    end

    # Returns `true` if it's a regular secondary structure, otherwise
    # `false`.
    #
    # See also `SecondaryStructureType#regular?`.
    #
    # ```
    # SecondaryStructure::RightHandedHelixAlpha.regular? # => true
    # SecondaryStructure::LeftHandedHelixAlpha.regular?  # => true
    # SecondaryStructure::BetaStrand.regular?            # => true
    # SecondaryStructure::Turn.regular?                  # => false
    # SecondaryStructure::Bend.regular?                  # => false
    # ```
    def regular? : Bool
      type.regular?
    end

    # Returns secondary structure type.
    #
    # ```
    # SecondaryStructure::RightHandedHelixAlpha.type # => Helical
    # SecondaryStructure::LeftHandedHelixAlpha.type  # => Helical
    # SecondaryStructure::BetaStrand.type            # => Extended
    # SecondaryStructure::Turn.type                  # => Coil
    # SecondaryStructure::Bend.type                  # => Coil
    # ```
    def type : SecondaryStructureType
      case self
      when .helix3_10?, .helix_alpha?, .helix_pi?
        SecondaryStructureType::Helical
      when .beta_bridge?, .beta_strand?, .helix2_7?, .polyproline?
        SecondaryStructureType::Extended
      else
        SecondaryStructureType::Coil
      end
    end

    {% for sec in %w(helix2_7 helix3_10 helix_alpha helix_pi) %}
      def {{sec.id}}?
        left_handed_{{sec.id}}? || right_handed_{{sec.id}}?
      end
    {% end %}
  end

  # Members are similar to simplified or reduced secondary structure
  # classification:
  #
  # - Helical (α-helix, π-helix, etc.)
  # - Extended (β-strand, polyproline, 2.2_7-helix, etc.)
  # - Coil (Bend, turn, etc.)
  enum SecondaryStructureType
    Coil
    Extended
    Helical

    # Returns one-letter secondary structure type code.
    #
    # Assignment codes are similar to those of simplified DSSP:
    #
    # - `'H'` : Helical
    # - `'E'` : Extended
    # - `'C'` : Coil
    def code : Char
      case self
      when .extended? then 'E'
      when .helical?  then 'H'
      else                 'C'
      end
    end

    # Returns `true` if it's a regular secondary structure type,
    # otherwise `false`.
    #
    # ```
    # SecondaryStructureType::Helical.regular?  # => true
    # SecondaryStructureType::Extended.regular? # => true
    # SecondaryStructureType::Coil.regular?     # => false
    # ```
    def regular? : Bool
      !coil?
    end
  end
end
