module Chem::Protein::DSSP
  private struct Helix
    enum Type
      None
      Start
      End
      StartEnd
      Middle

      def start? : Bool
        self == Start || self == StartEnd
      end
    end
  end
end
