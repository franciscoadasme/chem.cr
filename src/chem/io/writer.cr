module Chem::IO
  abstract class Writer
    abstract def <<(structure : Structure)

    macro inherited
      {% if @type.annotation(Chem::IO::FileType) %}
        macro finished
          \{% methods = @type.methods.select &.name.==("initialize") %}
          \{% if methods.select { |m| !m.args.empty? &&
                                      m.args[0].restriction.id == ::IO.id }.empty? \%}
            \{% @type.raise "abstract `def #{@type.superclass}#initialize(" \
                            "@io : IO, ...)` must be implemented by #{@type}" %}
          \{% elsif methods.size > 1 %}
            \{% @type.raise "Multiple `#initialize` methods not allowed in #{@type} " \
                            "having #{Chem::IO::FileType} annotation" %}
          \{% end %}

          \{% method = methods[0] %}
          \{% args = method.args[1..-1] %}
          \{% if arg = args.select(&.default_value.is_a?(Nop))[0] %}
            \{% method.raise "Argument `#{arg.name}` of `#{@type}#initialize(" \
                             "#{method.args.splat})` must have a default value" %}
          \{% end %}

          def initialize(io : ::IO, options : NamedTuple)
            if options.empty?
              initialize(io, \{{args.map(&.default_value).splat}})
            else
              initialize(
                io,
                \{% for arg in args %}
                  \{{arg.name}}: (options.has_key?(:\{{arg.name}}) ?
                    options[:\{{arg.name}}]?.not_nil! :
                    \{{arg.default_value}}),
                \{% end %}
              )
            end
          end
        end
      {% end %}
    end
  end
end
