module Chem
  abstract class IO::Writer(T)
    abstract def write(obj : T) : Nil

    property? sync_close = false
    getter? closed = false

    @io : ::IO

    def initialize(input : ::IO | Path | String, *, @sync_close : Bool = false)
      if input.is_a?(Path | String)
        input = File.new(input, "w")
        @sync_close = true
      end
      @io = input
    end

    def self.open(io : ::IO | Path | String, *args, sync_close : Bool = false, **options)
      writer = new io, *args, **options, sync_close: sync_close
      yield writer ensure writer.close
    end

    def close : Nil
      return if @closed
      @io.flush
      @closed = true
      @io.close if @sync_close
    end

    def format(str : String, *args, **options) : Nil
      @io.printf str, *args, **options
    end

    def formatl(str : String, *args, **options) : Nil
      format str, *args, **options
      @io << '\n'
    end

    protected def check_open
      raise Error.new "Closed IO" if closed?
    end
  end

  macro finished
    {% for writer in IO::Writer.all_subclasses.select(&.annotation(IO::FileType)) %}
      {% format = writer.annotation(IO::FileType)[:format].id.underscore %}

      {% type = writer.superclass.type_vars[0] %}
      {% keyword = type.class.id.ends_with?("Module") ? "module" : nil %}
      {% keyword = type < Reference ? "class" : "struct" unless keyword %}

      {{keyword.id}} ::{{type.id}}
        def to_{{format.id}}(*args, **options) : String
          String.build do |io|
            to_{{format.id}} io, *args, **options
          end
        end

        def to_{{format.id}}(output : ::IO | Path | String, *args, **options) : Nil
          {{writer}}.open(output, *args, **options) do |writer|
            writer.write self
          end
        end
      end
    {% end %}
  end
end
