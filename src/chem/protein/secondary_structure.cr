module Chem::Protein
  enum SecondaryStructure
    Bend
    BetaBridge
    BetaStrand
    LeftHandedHelix3_10
    LeftHandedHelixAlpha
    LeftHandedHelixGamma
    LeftHandedHelixPi
    None
    Polyproline
    RightHandedHelix3_10
    RightHandedHelixAlpha
    RightHandedHelixGamma
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
      when 'g'           then LeftHandedHelix3_10
      when 'h'           then LeftHandedHelixAlpha
      when 'f'           then LeftHandedHelixGamma
      when 'i'           then LeftHandedHelixPi
      when '0', 'C', 'c' then None
      when 'P', 'p'      then Polyproline
      when 'G'           then RightHandedHelix3_10
      when 'H'           then RightHandedHelixAlpha
      when 'F'           then RightHandedHelixGamma
      when 'I'           then RightHandedHelixPi
      when 'T', 't'      then Turn
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
      in .bend?                     then 'S'
      in .beta_bridge?              then 'B'
      in .beta_strand?              then 'E'
      in .left_handed_helix3_10?    then 'g'
      in .left_handed_helix_alpha?  then 'h'
      in .left_handed_helix_gamma?  then 'f'
      in .left_handed_helix_pi?     then 'i'
      in .none?                     then '0'
      in .polyproline?              then 'P'
      in .right_handed_helix3_10?   then 'G'
      in .right_handed_helix_alpha? then 'H'
      in .right_handed_helix_gamma? then 'F'
      in .right_handed_helix_pi?    then 'I'
      in .turn?                     then 'T'
      end
    end

    def color : Colorize::ColorRGB
      Colorize::ColorRGB.from_hex case self
      in .left_handed_helix3_10?, .right_handed_helix3_10?     then "#E88BC4"
      in .left_handed_helix_alpha?, .right_handed_helix_alpha? then "#E41A1C"
      in .left_handed_helix_pi?, .right_handed_helix_pi?       then "#6A3D9B"
      in .left_handed_helix_gamma?, .right_handed_helix_gamma? then "#F4A261"
      in .beta_strand?                                         then "#2A9D8F"
      in .polyproline?                                         then "#E9C46A"
      in .bend?, .beta_bridge?, .none?, .turn?                 then "#C8C8C8"
      end
    end

    # Returns `true` if secondary structures are equal.
    #
    # If `strict` is `true`, secondary structures are compared by their
    # identity, otherwise they're compared by their computed type.
    #
    # ```
    # SecondaryStructure::RightHandedHelixAlpha.equals?(:right_handed_helix_alpha) # => true
    # SecondaryStructure::RightHandedHelixAlpha.equals?(:right_handed_helix_pi)    # => false
    # SecondaryStructure::RightHandedHelixAlpha.equals?(:left_handed_helix_alpha)  # => false
    # SecondaryStructure::BetaStrand.equals?(:polyproline)                         # => true
    # SecondaryStructure::BetaStrand.equals?(:bend)                                # => false
    #
    # SecondaryStructure::RightHandedHelixAlpha.equals?(:right_handed_helix_pi, strict: false) # => true
    # SecondaryStructure::BetaStrand.equals?(:polyproline, strict: false)                      # => true
    # SecondaryStructure::BetaStrand.equals?(:bend, strict: false)                             # => false
    # ```
    def equals?(rhs : self, strict : Bool = true, handedness : Bool = true) : Bool
      if strict
        self == rhs
      elsif handedness
        type == rhs.type && self.handedness == rhs.handedness
      else
        type == rhs.type
      end
    end

    def handedness : Symbol?
      case self
      in .left_handed_helix3_10?,
         .left_handed_helix_alpha?,
         .left_handed_helix_gamma?,
         .left_handed_helix_pi?
        :left
      in .right_handed_helix3_10?,
         .right_handed_helix_alpha?,
         .right_handed_helix_gamma?,
         .right_handed_helix_pi?
        :right
      in .bend?,
         .beta_bridge?,
         .beta_strand?,
         .none?,
         .polyproline?,
         .turn?,
         nil
      end
    end

    # Returns nominal secondary structure's minimum size.
    def min_size : Int32
      case self
      when .beta_strand? then 2
      when .helix3_10?   then 3
      when .helix_alpha? then 4
      when .helix_gamma? then 3
      when .helix_pi?    then 5
      when .polyproline? then 3
      else                    1
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
      in .left_handed_helix3_10?, .left_handed_helix_alpha?, .left_handed_helix_pi?,
         .right_handed_helix3_10?, .right_handed_helix_alpha?, .right_handed_helix_pi?
        SecondaryStructureType::Helical
      in .beta_bridge?, .beta_strand?, .left_handed_helix_gamma?, .polyproline?,
         .right_handed_helix_gamma?
        SecondaryStructureType::Extended
      in .bend?, .none?, .turn?
        SecondaryStructureType::Coil
      end
    end

    {% for sec in %w(helix_gamma helix3_10 helix_alpha helix_pi) %}
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
      in .extended? then 'E'
      in .helical?  then 'H'
      in .coil?     then 'C'
      end
    end

    # Returns nominal secondary structure type's minimum size.
    def min_size : Int32
      case self
      in .extended? then 2
      in .helical?  then 3
      in .coil?     then 1
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

  abstract class SecondaryStructureCalculator
    def initialize(@structure : Structure)
    end

    abstract def assign : Nil

    def self.assign(structure : Structure, **options) : Nil
      new(structure, **options).assign
    end

    protected def reset_secondary_structure : Nil
      @structure.residues.reset_secondary_structure
    end
  end
end
