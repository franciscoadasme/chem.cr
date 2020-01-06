require "./periodic_table/macros"
require "./periodic_table/elements"

module Chem::PeriodicTable
  extend self

  def [](*args, **options) : Element
    self[*args, **options]? || unknown_element *args, **options
  end

  def []?(number : Int32) : Element?
    {% begin %}
      case number
      {% for name, i in @type.constants.select { |c| @type.constant(c).is_a?(Call) } %}
        {% if i < 118 %}
          when {{i + 1}}
            {{@type}}::{{name}}
        {% end %}
      {% end %}
      else
        nil
      end
    {% end %}
  end

  def []?(symbol : String | Char) : Element?
    {% begin %}
      case symbol.to_s.capitalize
      {% for name, i in @type.constants.select { |c| @type.constant(c).is_a?(Call) } %}
        {% if i < 118 %}
          when {{name.stringify}}
            {{@type}}::{{name}}
        {% end %}
      {% end %}
      else
        nil
      end
    {% end %}
  end

  def []?(*, name : String) : Element?
    {% begin %}
      case name
      {% for name, i in @type.constants.select { |c| @type.constant(c).is_a?(Call) } %}
        {% if i < 118 %}
          when {{@type}}::{{name}}.name
            {{@type}}::{{name}}
        {% end %}
      {% end %}
      else
        nil
      end
    {% end %}
  end

  # TODO rename to guess_element?
  # TODO test different atom names
  def []?(*, atom_name : String) : Element?
    atom_name = atom_name.lstrip("123456789").capitalize
    self[atom_name[0]]? || self[atom_name]?
  end

  def covalent_cutoff(atom : Atom, other : Atom) : Float64
    covalent_cutoff atom.element, other.element
  end

  # NOTE: The additional term (0.3 Å) is taken from the covalent radii reference,
  # which states that about 96% of the surveyed bonds are within three standard
  # deviations of the sum of the radii, where the found average standard deviation is
  # about 0.1 Å.
  def covalent_cutoff(ele : Element, other : Element) : Float64
    covalent_pair_dist_table[{ele, other}] ||= \
       (ele.covalent_radius + other.covalent_radius + 0.3) ** 2
  end

  def elements : Tuple
    {% begin %}
      {
        {% for name, i in @type.constants.select { |c| @type.constant(c).is_a?(Call) } %}
          {% if i < 118 %}
            {{@type}}::{{name}},
          {% end %}
        {% end %}
      }
    {% end %}
  end

  private def covalent_pair_dist_table : Hash(Tuple(Element, Element), Float64)
    @@covalent_pair_dist_table ||= {} of Tuple(Element, Element) => Float64
  end

  private def unknown_element(*args, **options)
    value = options.values.first? || args[0]?
    raise Error.new "Unknown element: #{value}"
  end
end
