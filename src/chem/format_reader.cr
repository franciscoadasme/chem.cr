module Chem
  abstract class FormatReader(T)
    abstract def read_entry : T

    property? sync_close = false
    getter? closed = false

    def initialize(io : ::IO, @sync_close : Bool = true)
      @io = TextIO.new io
    end

    def self.new(path : Path | String) : self
      new File.open(path), sync_close: true
    end

    def self.open(io : ::IO, sync_close : Bool = true, **options)
      reader = new io, **options, sync_close: sync_close
      yield reader ensure reader.close
    end

    def self.open(path : Path | String, **options)
      reader = new path, **options
      yield reader ensure reader.close
    end

    def close
      return if @closed
      @closed = true
      @io.close if @sync_close
    end

    def parse_exception(msg : String)
      raise ParseException.new msg
    end
  end

  abstract class Structure::Reader < FormatReader(Structure)
    include Iterator(Structure)

    abstract def skip_structure : Nil

    def initialize(input : ::IO,
                   @guess_topology : Bool = true,
                   sync_close : Bool = true)
      super input, sync_close
    end

    def self.new(path : Path | String, guess_topology : Bool = true) : self
      new File.open(path), guess_topology, sync_close: true
    end

    def each(indexes : Enumerable(Int), &block : Structure ->)
      (indexes.max + 1).times do |i|
        if i.in?(indexes)
          value = self.next
          raise IndexError.new if value.is_a?(Stop)
          yield value
        else
          skip_structure
        end
      end
    end

    def read_entry : Structure
      first? || parse_exception "Empty content"
    end

    def select(indexes : Enumerable(Int)) : Iterator(Structure)
      SelectByIndex(typeof(self)).new self, indexes
    end

    def skip(n : Int) : Iterator(Structure)
      raise ArgumentError.new "Negative size: #{n}" if n < 0
      SkipStructure(typeof(self)).new self, n
    end

    # Specialized iterator that creates/parses only selected structures by using
    # `Parser#skip_structure`, which doesn't parse skipped structures
    private class SelectByIndex(T)
      include Iterator(Structure)

      @indexes : Array(Int32)

      def initialize(@parser : T, indexes : Enumerable(Int))
        @current = 0
        @indexes = indexes.map(&.to_i).sort!
      end

      def next : Structure | Stop
        return stop if @indexes.empty?
        (@indexes.shift - @current).times do
          @parser.skip_structure
          @current += 1
        end
        value = @parser.next
        raise IndexError.new if value.is_a?(Stop)
        @current += 1
        value
      end
    end

    # Specialized iterator that uses `Parser#skip_structure` to avoid creating/parsing
    # skipped structures
    private class SkipStructure(T)
      include Iterator(Structure)

      def initialize(@parser : T, @n : Int32)
      end

      def next : Structure | Stop
        while @n > 0
          @n -= 1
          @parser.skip_structure
        end
        @parser.next
      end
    end
  end

  abstract class Spatial::Grid::Reader < FormatReader(Spatial::Grid)
    abstract def info : Spatial::Grid::Info
  end

  macro finished
    {% for reader in FormatReader.all_subclasses.select(&.annotation(IO::RegisterFormat)) %}
      {% format = reader.annotation(IO::RegisterFormat)[:format].id.underscore %}

      {% type = reader.ancestors.reject(&.type_vars.empty?)[0].type_vars[0] %}
      {% keyword = type.class.id.ends_with?("Module") ? "module" : nil %}
      {% keyword = type < Reference ? "class" : "struct" unless keyword %}

      {{keyword.id}} ::{{type.id}}
        def self.from_{{format.id}}(input : ::IO | Path | String, *args, **options) : self
          {{reader}}.open(input, *args, **options) do |reader|
            reader.read_entry
          end
        end
      end

      class ::Array(T)
        def self.from_{{format.id}}(input : ::IO | Path | String, *args, **options) : self
          {{reader}}.new(input, *args, **options).to_a
        end

        def self.from_{{format.id}}(input : ::IO | Path | String,
                                    indexes : Array(Int),
                                    *args,
                                    **options) : self
          ary = Array(Chem::Structure).new indexes.size
          {{reader}}.open(input, *args, **options) do |reader|
            reader.each(indexes) { |st| ary << st }
          end
          ary
        end
      end
    {% end %}
  end
end
