module Chem::IO
  # format : String
  # ext : Array(Tuple(String, Symbol))
  annotation FileType; end

  macro finished
    enum FileFormat
      {% writers = Writer.all_subclasses.select &.annotation(FileType) %}
      {% parsers = Parser.all_subclasses.select(&.annotation(FileType)) %}
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
      # FileFormat.from_stem("img2314") # => FileFormat::Image
      # FileFormat.from_stem("Imi") # => raises ArgumentError
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
      # FileFormat.from_stem?("img2314") # => FileFormat::Image
      # FileFormat.from_stem?("Imi") # => nil
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
