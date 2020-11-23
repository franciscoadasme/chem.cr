module Chem
  module IO::Reader(T)
    property? sync_close = false
    getter? closed = false

    abstract def read : T

    macro included
      setup_initializer_hook
    end

    def close
      return if @closed
      @closed = true
      @io.close if @sync_close
    end

    def parse_exception(msg : String)
      raise ParseException.new msg
    end

    private macro generate_initializer
      def self.new(path : Path | String, **options) : self
        new File.open(path), **options, sync_close: true
      end

      def self.open(io : ::IO, sync_close : Bool = true, **options)
        reader = new io, **options, sync_close: sync_close
        yield reader ensure reader.close
      end

      def self.open(path : Path | String, **options)
        reader = new path, **options
        yield reader ensure reader.close
      end
    end

    private macro setup_initializer_hook
      macro finished
        {% unless @type.module? || @type.abstract? %}
          generate_initializer
        {% end %}
      end
  
      macro included
        setup_initializer_hook
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

    protected def check_open
      raise ::IO::Error.new "Closed IO" if closed?
    end
  end

  module IO::MultiReader(T)
    include IO::Reader(T)

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

  abstract class Spatial::Grid::Reader
    include IO::Reader(Spatial::Grid)

    abstract def info : Spatial::Grid::Info
  end

  macro finished
    {% includers = IO::Reader.includers + IO::MultiReader.includers %}
    {% for reader in includers.select(&.annotation(IO::FileType)) %}
      {% type = reader.annotation(IO::FileType)[0].resolve %}
      {% keyword = "class" if type.class? %}
      {% keyword = "struct" if type.struct? %}
      {% format = reader.annotation(IO::FileType)[:format].id.underscore %}

      {{keyword.id}} ::{{type.id}}
        def self.from_{{format.id}}(input : ::IO | Path | String, *args, **options) : self
          {{reader}}.open(input, *args, **options) do |reader|
            reader.read
          end
        end
      end

      {% if reader < IO::MultiReader %}
        class ::Array(T)
          def self.from_{{format.id}}(input : ::IO | Path | String, *args, **options) : self
            {{reader}}.open(input, *args, **options) do |reader|
              ary = [] of T
              reader.each { |ele| ary << ele }
              ary
            end
          end

          def self.from_{{format.id}}(input : ::IO | Path | String, 
                                      indexes : Enumerable(Int),
                                      *args,
                                      **options) : self
            {{reader}}.open(input, *args, **options) do |reader|
              ary = [] of T
              reader.each(indexes) { |ele| ary << ele }
              ary
            end
          end
        end
      {% end %}
    {% end %}
  end
end
