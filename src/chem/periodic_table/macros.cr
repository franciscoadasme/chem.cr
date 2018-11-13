module Chem::PeriodicTable
  macro element(symbol, name, **options)
    {% elements = @type.constants.reject { |c| @type.constant(c).is_a? TypeNode } %}
    {% options[:atomic_number] = elements.size + 1 unless options[:atomic_number] %}
    {% options[:name] = name.stringify %}
    {% options[:symbol] = symbol.stringify %}

    {{@type}}::{{symbol.id}} = {{@type}}::Element.new {{options.double_splat}}

    class {{@type}}::Element
      def {{name.id.underscore.id}}?
        same? {{@type}}::{{symbol.id}}
      end
    end
  end
end
