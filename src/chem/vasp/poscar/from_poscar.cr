module Chem
  def Constraint.new(pull : VASP::Poscar::Parser) : Constraint?
    case {pull.read_bool, pull.read_bool, pull.read_bool}
    when {true, true, true}    then nil
    when {false, true, true}   then X
    when {true, false, true}   then Y
    when {true, true, false}   then Z
    when {false, false, true}  then XY
    when {false, true, false}  then XZ
    when {true, false, false}  then YZ
    when {false, false, false} then XYZ
    else                            raise "BUG: unreachable"
    end
  end

  struct Spatial::Vector
    def initialize(pull : VASP::Poscar::Parser)
      @x = pull.read_float
      @y = pull.read_float
      @z = pull.read_float
    end
  end

  class Structure::Builder
    def lattice(pull : VASP::Poscar::Parser) : Lattice
      lattice do
        a pull.scale_factor * pull.read_vector
        b pull.scale_factor * pull.read_vector
        c pull.scale_factor * pull.read_vector
      end
    end
  end
end

def Bool.new(pull : Chem::VASP::Poscar::Parser)
  pull.skip_whitespace
  case flag = pull.read
  when 'F' then false
  when 'T' then true
  else          pull.parse_exception "Invalid boolean"
  end
end
