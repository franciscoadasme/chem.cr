module Chem::PeriodicTable
  macro element(symbol, name, **options)
    {% elements = @type.constants.reject { |c| @type.constant(c).is_a? TypeNode } %}
    {% options[:atomic_number] = elements.size + 1 unless options[:atomic_number] %}
    {% options[:name] = name.stringify %}
    {% options[:symbol] = symbol.stringify %}

    {{@type}}::{{symbol.id}} = ::Chem::Element.new {{options.double_splat}}

    class ::Chem::Element
      # Returns `true` if the element is {{name}}, else `false`.
      def {{name.id.underscore.id}}?
        same? {{@type}}::{{symbol.id}}
      end
    end

    class ::Chem::Atom
      # Returns `true` if the atom's element is {{name}}, else `false`.
      def {{name.id.underscore.id}}?
        @element.{{name.id.underscore.id}}?
      end
    end
  end
end
