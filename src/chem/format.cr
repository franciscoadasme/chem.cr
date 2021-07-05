module Chem
  macro finished
    enum Format
      {% writers = FormatWriter.all_subclasses.select &.annotation(RegisterFormat) %}
      {% readers = FormatReader.all_subclasses.select(&.annotation(RegisterFormat)) %}
      {% annotations = (readers + writers).map &.annotation(RegisterFormat) %}
      {% file_formats = annotations.map(&.[:format].id).uniq.sort %}

      {% for format in file_formats %}
        {{format.id}}
      {% end %}

      {% for format in file_formats %}
        def {{format.id.downcase}}? : Bool
          self == {{format}}
        end
      {% end %}

      # Returns the file format associated with *extname*, or raises `ArgumentError`
      # otherwise.
      #
      # ```
      # @[RegisterFormat(format: Image, ext: %w(tiff png jpg))]
      # ...
      #
      # Format.from_ext("img.tiff") # => Format::Image
      # Format.from_ext("img.TIFF") # => Format::Image
      # Format.from_ext("img.png")  # => Format::Image
      # Format.from_ext("img.txt")  # => raises ArgumentError
      # ```
      #
      # NOTE: it performs a case-insensitive search so .tiff and .TIFF return the same.
      def self.from_ext(extname : String) : self
        from_ext?(extname) || raise ArgumentError.new "File format not found for #{extname}"
      end

      # Returns the file format associated with *extname*, or `nil` otherwise.
      #
      # ```
      # @[RegisterFormat(format: Image, ext: %w(tiff png jpg))]
      # ...
      #
      # Format.from_ext?("img.tiff") # => Format::Image
      # Format.from_ext?("img.TIFF") # => Format::Image
      # Format.from_ext?("img.png")  # => Format::Image
      # Format.from_ext?("img.txt")  # => nil
      # ```
      #
      # NOTE: it performs a case-insensitive search so .tiff and .TIFF return the same.
      def self.from_ext?(extname : String) : self?
        {% begin %}
          case extname.downcase
          {% for format in file_formats %}
            {% extensions = [] of MacroId %}
            {% for ann in annotations.select(&.[:format].id.==(format)) %}
              {% if extnames = ann[:ext] %}
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
      # @[RegisterFormat(format: Image, ext: %w(tiff png jpg), names: %w(IMG*))]
      # ...
      #
      # Format.from_filename("IMG_2314.tiff") # => Format::Image
      # Format.from_filename("IMG_2314.png")  # => Format::Image
      # Format.from_filename("IMG_2314")      # => Format::Image
      # Format.from_filename("img_2314")      # => Format::Image
      # Format.from_filename("img2314")       # => Format::Image
      # Format.from_filename("Imi")           # => raises ArgumentError
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
      # @[RegisterFormat(format: Image, ext: %w(tiff png jpg), names: %w(IMG*))]
      # ...
      #
      # Format.from_filename?("IMG_2314.tiff") # => Format::Image
      # Format.from_filename?("IMG_2314.png")  # => Format::Image
      # Format.from_filename?("IMG_2314")      # => Format::Image
      # Format.from_filename?("img_2314")      # => Format::Image
      # Format.from_filename?("img2314")       # => Format::Image
      # Format.from_filename?("Imi")           # => nil
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
      # @[RegisterFormat(format: Image, names: %w(IMG*))]
      # ...
      #
      # Format.from_stem("IMG_2314") # => Format::Image
      # Format.from_stem("img_2314") # => Format::Image
      # Format.from_stem("img2314")  # => Format::Image
      # Format.from_stem("Imi")      # => raises ArgumentError
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
      # @[RegisterFormat(format: Image, names: %w(IMG*))]
      # ...
      #
      # Format.from_stem?("IMG_2314") # => Format::Image
      # Format.from_stem?("img_2314") # => Format::Image
      # Format.from_stem?("img2314")  # => Format::Image
      # Format.from_stem?("Imi")      # => nil
      # ```
      def self.from_stem?(stem : String) : self?
        stem = stem.camelcase.downcase
        {% for format in file_formats %}
          {% file_names = [] of StringLiteral %}
          {% for ann in annotations.select(&.[:format].id.==(format)) %}
            {% if names = ann[:names] %}
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
            {% for ann in annotations.select(&.[:format].id.==(format)) %}
              {% if extnames = ann[:ext] %}
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
