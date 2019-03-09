module Chem
  def Constraint.new(pull : VASP::Poscar::PullParser) : Constraint
    case {pull.read_bool, pull.read_bool, pull.read_bool}
    when {true, true, true}    then None
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

  def VASP::Poscar::CoordinateSystem.new(pull : VASP::Poscar::PullParser)
    pull.skip_whitespace
    line = pull.read_line
    case line[0].downcase
    when 'c', 'k' # cartesian
      CoordinateSystem::Cartesian
    when 'd' # direct
      CoordinateSystem::Fractional
    else
      pull.fail "Invalid coordinate type: #{line}"
    end
  end

  struct Spatial::Vector
    def initialize(pull : VASP::Poscar::PullParser)
      @x = pull.read_float
      @y = pull.read_float
      @z = pull.read_float
    end
  end

  class Structure::Builder
    def lattice(pull : VASP::Poscar::PullParser) : Lattice
      lattice do
        scale by: pull.read_float
        a pull.read_vector
        b pull.read_vector
        c pull.read_vector
      end
    end
  end
end

def Bool.new(pull : Chem::VASP::Poscar::PullParser)
  pull.skip_whitespace
  case flag = pull.read_char
  when 'F'
    false
  when 'T'
    true
  else
    pull.fail "Invalid boolean: #{flag}"
  end
end
