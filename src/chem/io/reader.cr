module Chem
  module IO::Reader(T)
    include IOWrapper

    abstract def read : T

    @io : ::IO

    def parse_exception(msg : String)
      raise ParseException.new msg
    end

    protected def check_eof
      raise ::IO::EOFError.new if @io.peek.nil?
    end
  end

  module IO::TextReader(T)
    @io : TextIO

    macro included
      macro finished
        \{% assigns = ASSIGNS.sort_by do |decl|
             has_explicit_value =
               decl.type.is_a?(Metaclass) ||
                 decl.type.types.map(&.id).includes?(Nil.id) ||
                 decl.value ||
                 decl.value == nil ||
                 decl.value == false
             has_explicit_value ? 1 : 0
           end %}

        def initialize(
          io : ::IO,
          \{% for decl in assigns %}
            @\{{decl}},
          \{% end %}
          @sync_close : Bool = false,
        )
          @io = IO::TextIO.new io
        end
      end
    end

    protected def check_eof(skip_lines : Bool = true)
      if skip_lines
        @io.skip_whitespace
      else
        @io.skip_spaces
      end
      raise ::IO::EOFError.new if @io.eof?
    end
  end

  module IO::MultiReader(T)
    abstract def read_next : T?
    abstract def skip : Nil

    def each(& : T ->)
      while ele = read_next
        yield ele
      end
    end

    def each(indexes : Enumerable(Int), & : T ->)
      (indexes.max + 1).times do |i|
        if i.in?(indexes)
          ele = read_next
          raise IndexError.new unless ele
          yield ele
        else
          skip
        end
      end
    end

    def read : T
      read_next || raise ::IO::EOFError.new
    end
  end

  module Spatial::Grid::Reader
    abstract def info : Spatial::Grid::Info
  end
end
