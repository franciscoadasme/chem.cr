require "./periodic_table/*"

module Chem::PeriodicTable
  class UnknownElement < Exception
  end

  def self.[](*args, **options) : Element
    element *args, **options
  end

  def self.[]?(*args, **options) : Element?
    element *args, **options
  rescue UnknownElement
    nil
  end

  def self.element(number : Int32) : Element
    {% begin %}
      case number
      {% for constant, index in @type.constant("Elements").constants %}
        when {{ index + 1 }}
          {{ @type }}::Elements::{{ constant }}
      {% end %}
      else
        unknown_element number
      end
    {% end %}
  end

  def self.element(symbol : Char) : Element
    element symbol.to_s
  end

  def self.element(symbol : String) : Element
    {% begin %}
      case symbol.capitalize
      {% for constant in @type.constant("Elements").constants %}
        when {{constant.stringify}}
          {{@type}}::Elements::{{constant}}
      {% end %}
      else
        unknown_element symbol
      end
    {% end %}
  end

  # TODO rename to guess_element?
  # TODO test different atom names
  def self.element(*, atom_name : String) : Element
    atom_name = atom_name.lstrip("123456789").capitalize
    element atom_name[0]
  rescue UnknownElement
    element atom_name
  end

  def self.element(*, name : String) : Element
    {% begin %}
      case name
      {% for constant in @type.constant("Elements").constants %}
        when {{@type}}::Elements::{{constant}}.name
          {{@type}}::Elements::{{constant}}
      {% end %}
      else
        unknown_element name
      end
    {% end %}
  end

  def self.elements : Tuple
    {% begin %}
      {
        {% for constant in @type.constant("Elements").constants %}
          {{ @type }}::Elements::{{ constant }},
        {% end %}
      }
    {% end %}
  end

  private def self.unknown_element(value)
    raise UnknownElement.new "Unknown element: #{value}"
  end
end
