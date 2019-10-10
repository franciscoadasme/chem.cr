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

    def parse_exception(msg : String)
      raise ParseException.new msg
    end
  end

  module ParserWithLocation
    @prev_pos : Int32 | Int64 = 0

    def parse_exception(msg : String)
      loc, lines = guess_location
      raise ParseException.new msg, loc, lines
    end

    private def guess_location(nlines : Int = 3) : {Location, Array(String)}
      current_pos = @io.pos.to_i
      line_number = 0
      column_number = current_pos
      lines = Array(String).new nlines
      @io.rewind
      @io.each_line(chomp: false) do |line|
        line_number += 1
        lines.shift if lines.size == nlines
        lines << line.chomp
        break if @io.pos > current_pos
        column_number -= line.size
      end
      @io.pos = current_pos

      size = current_pos - @prev_pos
      {Location.new(line_number, column_number - size + 1, size), lines}
    end

    private def read(& : -> T) : T forall T
      current_pos = @io.pos
      value = yield
      @prev_pos = current_pos
      value
    end
  end
end
