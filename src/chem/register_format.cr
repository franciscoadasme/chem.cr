module Chem
  # Registers a file format.
  #
  # A file type associates extensions and/or file names with a file format, and links
  # the latter to the annotated classes. If the file format does not exist, it is
  # registered.
  #
  # This annotation accepts the file format (required), and either an array of
  # extensions (without leading dot) or an array of file names, or both. File names can
  # include wildcards (*) to denote either prefix (e.g., "Foo*"), suffix (e.g., "*Bar"),
  # or both (e.g., "*Baz*").
  #
  # ```
  # @[RegisterFormat(format: Log, ext: %w(txt log out), names: %w(LOG *OUT))]
  # class LogParser
  # end
  # ```
  annotation RegisterFormat; end
end

macro finished
  {% readers = Chem::FormatReader.all_subclasses.select &.annotation(Chem::RegisterFormat) %}
  {% writers = Chem::FormatWriter.all_subclasses.select &.annotation(Chem::RegisterFormat) %}
  {% klasses = readers + writers %}
  {% annotations = klasses.map &.annotation(Chem::RegisterFormat) %}

  # check missing annotation arguments
  {% for klass in klasses %}
    {% t = klass.annotation(Chem::RegisterFormat) %}
    {% klass.raise "RegisterFormat annotation on #{klass} must set `format`" unless t[:format] %}
    {% if !t[:ext] && !t[:names] %}
      {% klass.raise "RegisterFormat annotation on #{klass} must set either `ext` or `names`" %}
    {% end %}
  {% end %}

  # check duplicate file formats
  {% file_formats = annotations.map(&.[:format].id).uniq.sort %}
  {% for format in file_formats %}
    {% for ary in [readers, writers] %}
      {% ary = ary.select &.annotation(Chem::RegisterFormat)[:format].id.==(format) %}
      {% if ary.size > 1 %}
        {% ary[1].raise "#{format} file format is already associated with " \
                        "#{ary[0]}" %}
      {% end %}
    {% end %}
  {% end %}

  # check duplicate file extensions (different file formats)
  {% format_by_ext = {} of String => MacroId %}
  {% klass_by_ext = {} of String => MacroId %}
  {% format_by_name = {} of String => MacroId %}
  {% klass_by_name = {} of String => MacroId %}
  {% for klass in klasses %}
    {% ann = klass.annotation(Chem::RegisterFormat) %}
    {% format = ann[:format].id %}
    {% if extnames = ann[:ext] %}
      {% for ext in extnames %}
        {% ann.raise "File extensions registered by #{klass} must start \
                      with a dot" unless ext.starts_with?(".") %}

        {% if (other = format_by_ext[ext]) && other != format %}
          {% klass.raise ".#{ext.id} extension declared in #{klass} is already " \
                         "associated with file format #{other} via " \
                         "#{klass_by_ext[ext]}" %}
        {% end %}
        {% format_by_ext[ext] = format %}
        {% klass_by_ext[ext] = klass %}
      {% end %}
    {% end %}

    {% if names = ann[:names] %}
      {% for name in names %}
        {% key = name.tr("*", "").camelcase.underscore %}
        {% if (other = format_by_name[key]) && other != format %}
          {% klass.raise "File name #{name} declared in #{klass} is already " \
                         "associated with file format #{other} via " \
                         "#{klass_by_name[name]}" %}
        {% end %}
        {% format_by_name[key] = format %}
        {% klass_by_name[key] = klass %}
      {% end %}
    {% end %}
  {% end %}

  {% for reader in readers %}
    {% format = reader.annotation(Chem::RegisterFormat)[:format].id.underscore %}

    {% type = reader.ancestors.reject(&.type_vars.empty?)[0].type_vars[0] %}
    {% keyword = "module" if type.module? %}
    {% keyword = "class" if type.class? %}
    {% keyword = "struct" if type.struct? %}

    {{keyword.id}} {{type.id}}
      def self.from_{{format.id}}(input : IO | Path | String, *args, **options) : self
        {{reader}}.open(input, *args, **options) do |reader|
          reader.read_entry
        end
      end
    end

    class Array(T)
      def self.from_{{format.id}}(input : IO | Path | String, *args, **options) : self
        {{reader}}.new(input, *args, **options).to_a
      end

      def self.from_{{format.id}}(input : IO | Path | String,
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

  {% for writer in writers %}
    {% format = writer.annotation(Chem::RegisterFormat)[:format].id.downcase %}

    {% type = writer.superclass.type_vars[0] %}
    {% keyword = "module" if type.module? %}
    {% keyword = "class" if type.class? %}
    {% keyword = "struct" if type.struct? %}

    {{keyword.id}} {{type.id}}
      def to_{{format.id}}(*args, **options) : String
        String.build do |io|
          to_{{format.id}} io, *args, **options
        end
      end

      def to_{{format.id}}(output : IO | Path | String, *args, **options) : Nil
        {{writer}}.open(output, *args, **options) do |writer|
          writer.write self
        end
      end
    end
  {% end %}
end
