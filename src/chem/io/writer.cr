module Chem
  abstract class IO::Writer
    property? sync_close = false
    getter? closed = false

    def initialize(@io : ::IO, @sync_close : Bool = false)
    end

    def self.new(path : Path | String, **options)
      new File.new(path, "w"), **options, sync_close: true
    end

    def self.open(io : ::IO, sync_close : Bool = false, **options)
      writer = new io, **options, sync_close: sync_close
      yield writer ensure writer.close
    end

    def self.open(filename : Path | String, **options)
      writer = new filename
      yield writer ensure writer.close
    end

    def close : Nil
      return if @closed
      @closed = true
      @io.close if @sync_close
    end

    protected def check_open
      raise Error.new "Closed IO" if closed?
    end
  end

  abstract class Structure::Writer < IO::Writer
    abstract def write(atoms : AtomCollection) : Nil
  end

  macro finished
    {% for writer in Structure::Writer.subclasses.select(&.annotation(IO::FileType)) %}
      {% format = writer.annotation(IO::FileType)[:format].id.underscore %}

      module AtomCollection
        def to_{{format.id}}(**options) : String
          String.build do |io|
            to_{{format.id}} io, **options
          end
        end

        def to_{{format.id}}(output : ::IO | Path | String, **options) : Nil
          {{writer}}.open(output, **options) do |writer|
            writer.write self
          end
        end
      end
    {% end %}
  end
end
