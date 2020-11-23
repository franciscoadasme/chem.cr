module Chem
  module IO::Reader(T)
    property? sync_close = false
    getter? closed = false

    abstract def read : T

    macro included
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

    def close
      return if @closed
      @closed = true
      @io.close if @sync_close
    end

    def parse_exception(msg : String)
      raise ParseException.new msg
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

  abstract class Spatial::Grid::Reader
    include IO::Reader(Spatial::Grid)

    abstract def info : Spatial::Grid::Info
  end

  macro finished
    {% for reader in IO::Reader.includers.select(&.annotation(IO::FileType)) %}
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
    {% end %}
  end
end
