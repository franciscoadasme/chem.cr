module Chem
  module IO::Writer(T)
    include IOWrapper

    FILE_MODE = "w"

    abstract def write(obj : T) : Nil

    @io : ::IO

    def format(str : String, *args, **options) : Nil
      @io.printf str, *args, **options
    end

    def formatl(str : String, *args, **options) : Nil
      format str, *args, **options
      @io << '\n'
    end
  end

  macro finished
    {% for writer in IO::Writer.includers.select(&.annotation(IO::FileType)) %}
      {% type = writer.annotation(IO::FileType)[:encoded].resolve %}
      {% keyword = "module" if type.module? %}
      {% keyword = "class" if type.class? %}
      {% keyword = "struct" if type.struct? %}
      {% format = writer.annotation(IO::FileType)[:format].id.downcase %}

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
