module Chem::IO
  # Marks a class as a provider of a file format.
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
  # @[FileType(format: Log, ext: %w(txt log out), names: %w(LOG *OUT))]
  # class LogParser
  # end
  # ```
  annotation FileType; end

  macro finished
    enum FileFormat
      {% writers = Writer.all_subclasses.select &.annotation(FileType) %}
      {% readers = Reader.all_subclasses.select(&.annotation(FileType)) %}
      {% klasses = readers + writers %}
      {% file_types = klasses.map &.annotation(IO::FileType) %}

      # check missing annotation arguments
      {% for klass in klasses %}
        {% t = klass.annotation(FileType) %}
        {% klass.raise "FileType annotation on #{klass} must set `format`" unless t[:format] %}
        {% if !t[:ext] && !t[:names] %}
          {% klass.raise "FileType annotation on #{klass} must set either `ext` or `names`" %}
        {% end %}
      {% end %}

      # check duplicate file formats
      {% file_formats = file_types.map(&.[:format].id).uniq.sort %}
      {% for format in file_formats %}
        {% for ary in [readers, writers] %}
          {% ary = ary.select &.annotation(IO::FileType)[:format].id.==(format) %}
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
        {% format = klass.annotation(IO::FileType)[:format].id %}
        {% if extnames = klass.annotation(IO::FileType)[:ext] %}
          {% for ext in extnames %}
            {% if (other = format_by_ext[ext]) && other != format %}
              {% klass.raise ".#{ext.id} extension declared in #{klass} is already " \
                             "associated with file format #{other} via " \
                             "#{klass_by_ext[ext]}" %}
            {% end %}
            {% format_by_ext[ext] = format %}
            {% klass_by_ext[ext] = klass %}
          {% end %}
        {% end %}

        {% if names = klass.annotation(IO::FileType)[:names] %}
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

      {% for format in file_formats %}
        {{format.id}}
      {% end %}

      # Returns the file format associated with *extname*, or raises `ArgumentError`
      # otherwise.
      #
      # ```
      # @[FileType(format: Image, ext: %w(tiff png jpg))]
      # ...
      #
      # FileFormat.from_ext("img.tiff") # => FileFormat::Image
      # FileFormat.from_ext("img.TIFF") # => FileFormat::Image
      # FileFormat.from_ext("img.png")  # => FileFormat::Image
      # FileFormat.from_ext("img.txt")  # => raises ArgumentError
      # ```
      #
      # NOTE: it performs a case-insensitive search so .tiff and .TIFF return the same.
      def self.from_ext(extname : String) : self
        from_ext?(extname) || raise ArgumentError.new "File format not found for #{extname}"
      end

      # Returns the file format associated with *extname*, or `nil` otherwise.
      #
      # ```
      # @[FileType(format: Image, ext: %w(tiff png jpg))]
      # ...
      #
      # FileFormat.from_ext?("img.tiff") # => FileFormat::Image
      # FileFormat.from_ext?("img.TIFF") # => FileFormat::Image
      # FileFormat.from_ext?("img.png")  # => FileFormat::Image
      # FileFormat.from_ext?("img.txt")  # => nil
      # ```
      #
      # NOTE: it performs a case-insensitive search so .tiff and .TIFF return the same.
      def self.from_ext?(extname : String) : self?
        {% begin %}
          case extname.downcase
          {% for format in file_formats %}
            {% extensions = [] of MacroId %}
            {% for file_type in file_types.select(&.[:format].id.==(format)) %}
              {% if extnames = file_type[:ext] %}
                {% for ext in extnames %}
                  {% extensions << ext %}
                {% end %}
              {% end %}
            {% end %}
            {% unless extensions.empty? %}
              when {{extensions.uniq.map { |ext| ".#{ext.downcase.id}" }.splat}}
                {{format}}
            {% end %}
          {% end %}
          end
        {% end %}
      end

      # Returns the file format associated with *filename*, or raises `ArgumentError`
      # otherwise.
      #
      # It first looks up the file format associated with the extension in *filename*
      # via `.from_ext?`. If this yields no result, then it executes a case-insensitive
      # search with the stem in *filename* via `.from_stem?`.
      #
      # ```
      # @[FileType(format: Image, ext: %w(tiff png jpg), names: %w(IMG*))]
      # ...
      #
      # FileFormat.from_filename("IMG_2314.tiff") # => FileFormat::Image
      # FileFormat.from_filename("IMG_2314.png")  # => FileFormat::Image
      # FileFormat.from_filename("IMG_2314")      # => FileFormat::Image
      # FileFormat.from_filename("img_2314")      # => FileFormat::Image
      # FileFormat.from_filename("img2314")       # => FileFormat::Image
      # FileFormat.from_filename("Imi")           # => raises ArgumentError
      # ```
      def self.from_filename(filename : Path | String) : self
        format = from_filename? filename
        format || raise ArgumentError.new "File format not found for #{filename}"
      end

      # Returns the file format associated with *filename*, or `nil` otherwise.
      #
      # It first looks up the file format associated with the extension in *filename*
      # via `.from_ext?`. If this yields no result, then it executes a case-insensitive
      # search with the stem in *filename* via `.from_stem?`.
      #
      # ```
      # @[FileType(format: Image, ext: %w(tiff png jpg), names: %w(IMG*))]
      # ...
      #
      # FileFormat.from_filename?("IMG_2314.tiff") # => FileFormat::Image
      # FileFormat.from_filename?("IMG_2314.png")  # => FileFormat::Image
      # FileFormat.from_filename?("IMG_2314")      # => FileFormat::Image
      # FileFormat.from_filename?("img_2314")      # => FileFormat::Image
      # FileFormat.from_filename?("img2314")       # => FileFormat::Image
      # FileFormat.from_filename?("Imi")           # => nil
      # ```
      def self.from_filename?(filename : Path | String) : self?
        filename = Path[filename] unless filename.is_a?(Path)
        extname = filename.extension
        from_ext?(extname) || from_stem?(filename.basename(extname))
      end

      # Returns the file format associated with *stem*, or raises `ArgumentError`
      # otherwise.
      #
      # The comparison is made using `String#camelcase` and `String#downcase`, so a file
      # format named `ChgCar` will match `"CHGCAR"`, `"ChgCar"`, `"chgcar"`, `"CHG_CAR"`
      # and `"chg_car"`.
      #
      # ```
      # @[FileType(format: Image, names: %w(IMG*))]
      # ...
      #
      # FileFormat.from_stem("IMG_2314") # => FileFormat::Image
      # FileFormat.from_stem("img_2314") # => FileFormat::Image
      # FileFormat.from_stem("img2314")  # => FileFormat::Image
      # FileFormat.from_stem("Imi")      # => raises ArgumentError
      # ```
      def self.from_stem(stem : Path | String) : self
        from_stem?(stem) || raise ArgumentError.new "File format not found for #{stem}"
      end

      # Returns the file format associated with *stem*, or `nil` otherwise.
      #
      # The comparison is made using `String#camelcase` and `String#downcase`, so a file
      # format named `ChgCar` will match `"CHGCAR"`, `"ChgCar"`, `"chgcar"`, `"CHG_CAR"`
      # and `"chg_car"`.
      #
      # ```
      # @[FileType(format: Image, names: %w(IMG*))]
      # ...
      #
      # FileFormat.from_stem?("IMG_2314") # => FileFormat::Image
      # FileFormat.from_stem?("img_2314") # => FileFormat::Image
      # FileFormat.from_stem?("img2314")  # => FileFormat::Image
      # FileFormat.from_stem?("Imi")      # => nil
      # ```
      def self.from_stem?(stem : String) : self?
        stem = stem.camelcase.downcase
        {% for format in file_formats %}
          {% file_names = [] of StringLiteral %}
          {% for file_type in file_types.select(&.[:format].id.==(format)) %}
            {% if names = file_type[:names] %}
              {% for name in names %}
                {% file_names << name.id.stringify.camelcase.downcase %}
              {% end %}
            {% end %}
          {% end %}

          {% for name in file_names.uniq.sort %}
            {% if name =~ /\*\w+\*/ %}
              return {{format}} if stem.includes? {{name[1..-2]}}
            {% elsif name.starts_with? "*" %}
              return {{format}} if stem.ends_with? {{name[1..-1]}}
            {% elsif name.ends_with? "*" %}
              return {{format}} if stem.starts_with? {{name[0..-2]}}
            {% else %}
              return {{format}} if stem == {{name}}
            {% end %}
          {% end %}
        {% end %}
      end

      def extnames : Array(String)
        {% begin %}
          case self
          {% for format in file_formats %}
            {% extensions = [] of MacroId %}
            {% for file_type in file_types.select(&.[:format].id.==(format)) %}
              {% if extnames = file_type[:ext] %}
                {% for ext in extnames %}
                  {% extensions << ext %}
                {% end %}
              {% end %}
            {% end %}
            {% unless extensions.empty? %}
              when {{format}}
                {{extensions.uniq.map { |ext| ".#{ext.id}" }}}
            {% end %}
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
