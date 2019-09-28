module Chem::IO
  abstract class Parser
    abstract def each_structure(&block : Structure ->)
    abstract def each_structure(indexes : Indexable(Int), &block : Structure ->)
    abstract def parse : Structure

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

          def initialize(content : String, **options)
            initialize ::IO::Memory.new(content), **options
          end

          def initialize(content : String, options : NamedTuple)
            initialize ::IO::Memory.new(content), options
          end
        end
      {% end %}
    end

    def eof? : Bool
      if bytes = @io.peek
        bytes.empty?
      else
        true
      end
    end

    def fail(msg : String)
      line_number, column_number = guess_location
      parse_exception "#{msg} at #{line_number}:#{column_number}"
    end

    private def guess_location : {Int32, Int32}
      prev_pos = @io.pos
      @io.rewind
      text = read_chars prev_pos
      {text.count('\n') + 1, text.size - (text.rindex('\n') || 0)}
    end

    def parse(index : Int) : Structure
      parse([index]).first
    end

    def parse(indexes : Array(Int)) : Array(Structure)
      ary = [] of Structure
      each_structure(indexes) { |structure| ary << structure }
      ary
    end

    def parse_all : Array(Structure)
      ary = [] of Structure
      each_structure { |structure| ary << structure }
      ary
    end

    protected def parse_exception(msg : String)
      raise IO::ParseException.new msg
    end
  end
end
