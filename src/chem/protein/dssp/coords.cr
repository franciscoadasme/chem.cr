module Chem::Protein::DSSP
  private struct Coords
    getter c : Spatial::Vector
    getter ca : Spatial::Vector
    getter h : Spatial::Vector
    getter n : Spatial::Vector
    getter o : Spatial::Vector

    def initialize(residue : Residue)
      @n = residue["N"]?.as(Atom).coords
      @h = Coords.guess_hydrogen residue
      @c = residue["C"]?.as(Atom).coords
      @o = residue["O"]?.as(Atom).coords
      @ca = residue["CA"]?.as(Atom).coords
    end

    def self.guess_hydrogen(residue : Residue) : Spatial::Vector
      r_n = residue["N"]?.as(Atom).coords
      return r_n if residue.name == "PRO"
      return r_n unless prev_res = residue.previous
      return r_n unless carbon = prev_res["C"]?
      return r_n unless oxygen = prev_res["O"]?
      r_n + ((carbon.coords - oxygen.coords) / Spatial.distance(carbon, oxygen))
    end
  end
end
