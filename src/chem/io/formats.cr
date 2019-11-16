module Chem::IO
  # format : String
  # ext : Array(Tuple(String, Symbol))
  annotation FileType; end

  macro finished
    enum FileFormat
      {% writers = Writer.subclasses.select &.annotation(FileType) %}
      {% parsers = Parser.subclasses.select(&.annotation(FileType)) %}
      {% klasses = parsers + writers %}
      {% file_types = klasses.map &.annotation(IO::FileType) %}

      # check missing annotation arguments
      {% for klass in klasses %}
        {% args = {format: String, ext: Array(Symbol)} %}
        {% for name, type in args %}
          {% unless klass.annotation(FileType)[name] %}
            {% klass.raise "Named argument `#{name} : #{type}` of " \
                           "#{FileType} annotation must be set by #{klass}" %}
          {% end %}
        {% end %}
      {% end %}

      # check duplicate file formats
      {% file_formats = file_types.map(&.[:format].id).uniq.sort %}
      {% for format in file_formats %}
        {% for ary in [parsers, writers] %}
          {% ary = ary.select &.annotation(IO::FileType)[:format].id.==(format) %}
          {% if ary.size > 1 %}
            {% ary[1].raise "#{format} file format is already associated with " \
                            "#{ary[0]}" %}
          {% end %}
        {% end %}
      {% end %}

      # check duplicate file extensions (different file formats)
      {% formats_by_ext = {} of String => MacroId %}
      {% klasses_by_ext = {} of String => MacroId %}
      {% for klass in klasses %}
        {% format = klass.annotation(IO::FileType)[:format].id %}
        {% for ext in klass.annotation(IO::FileType)[:ext] %}
          {% if (other = formats_by_ext[ext]) && other != format %}
            {% klass.raise ".#{ext.id} extension declared in #{klass} is already " \
                           "associated with file format #{other} via " \
                           "#{klasses_by_ext[ext]}" %}
          {% end %}
          {% formats_by_ext[ext] = format %}
          {% klasses_by_ext[ext] = klass %}
        {% end %}
      {% end %}

      {% for format in file_formats %}
        {{format.id}}
      {% end %}

      def self.from_ext(extname : String) : self
        from_ext?(extname) || raise "Unknown file extension: #{extname}"
      end

      def self.from_ext?(extname : String) : self?
        {% begin %}
          case extname
          {% for format in file_formats %}
            {% extensions = [] of MacroId %}
            {% for file_type in file_types.select(&.[:format].id.==(format)) %}
              {% for ext in file_type[:ext] %}
                {% extensions << ext %}
              {% end %}
            {% end %}
            when {{extensions.uniq.map { |ext| ".#{ext.id}" }.splat}}
              {{format}}
          {% end %}
          else
            nil
          end
        {% end %}
      end

      def extnames : Array(String)
        {% begin %}
          case self
          {% for format in file_formats %}
            {% extensions = [] of MacroId %}
            {% for file_type in file_types.select(&.[:format].id.==(format)) %}
              {% for ext in file_type[:ext] %}
                {% extensions << ext %}
              {% end %}
            {% end %}
            when {{format}}
              {{extensions.uniq.map { |ext| ".#{ext.id}" }}}
          {% end %}
          else
            raise "BUG: unreachable"
          end
        {% end %}
      end
    end
  end
end

require "./formats/*"
