module Chem
  class Atom
    def initialize(pull : VASP::Poscar::PullParser)
      @index = pull.current_index
      @serial = @index + 1
      @element = pull.current_element
      @name = "#{@element.symbol}#{pull.element_count[@element.symbol] += 1}"
      @coords = pull.read_coords
      @constraint = pull.read_constraint?
      @residue = pull.current_residue
    end
  end

  def Constraint.new(pull : VASP::Poscar::PullParser)
    Constraint.new case {pull.read_bool, pull.read_bool, pull.read_bool}
    when {true, true, true}    then Direction::None
    when {false, true, true}   then Direction::X
    when {true, false, true}   then Direction::Y
    when {true, true, false}   then Direction::Z
    when {false, false, true}  then Direction::XY
    when {false, true, false}  then Direction::XZ
    when {true, false, false}  then Direction::YZ
    when {false, false, false} then Direction::XYZ
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

  class Lattice
    def initialize(pull : VASP::Poscar::PullParser)
      @scale_factor = pull.read_float
      @a = pull.read_vector
      @b = pull.read_vector
      @c = pull.read_vector
    end
  end

  struct Spatial::Vector
    def initialize(pull : VASP::Poscar::PullParser)
      @x = pull.read_float
      @y = pull.read_float
      @z = pull.read_float
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
