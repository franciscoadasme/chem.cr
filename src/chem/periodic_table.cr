require "./err"
require "./periodic_table/*"

module Chem::PeriodicTable
  extend self

  def [](*args, **options) : Element
    self[*args, **options]? || unknown_element *args, **options
  end

  def []?(number : Int32) : Element?
    {% begin %}
      case number
      {% for name, index in @type.constants %}
        {% unless @type.constant(name).is_a? TypeNode %}
          when {{index}}
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
      {% for name in @type.constants %}
        {% unless @type.constant(name).is_a? TypeNode %}
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
      {% for name in @type.constants %}
        {% unless @type.constant(name).is_a? TypeNode %}
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

  def elements : Tuple
    {% begin %}
      {
        {% for name in @type.constants %}
          {% unless @type.constant(name).is_a? TypeNode %}
            {{@type}}::{{name}},
          {% end %}
        {% end %}
      }
    {% end %}
  end

  private def unknown_element(*args, **options)
    value = options.values.first? || args[0]?
    raise Error.new "Unknown element: #{value}"
  end
end
