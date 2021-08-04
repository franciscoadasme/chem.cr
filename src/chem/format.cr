module Chem
  macro finished
    enum Format
      {% for format in FORMAT_TYPES.map(&.constant("FORMAT_NAME")).sort %}
        {{format.id}}
      {% end %}

      {% for format in FORMAT_TYPES %}
        def {{format.constant("FORMAT_METHOD_NAME").id}}? : Bool
          self == {{format.constant("FORMAT_NAME").id}}
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
          {% for type in FORMAT_TYPES %}
            {% if extnames = type.annotation(RegisterFormat)[:ext] %}
              when {{extnames.splat}}
                {{type.constant("FORMAT_NAME").id}}
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
        {% begin %}
          case stem.camelcase.downcase
          {% for type in FORMAT_TYPES %}
            {% format = type.constant("FORMAT_NAME").id %}
            {% names = type.annotation(RegisterFormat)[:names] || [] of Nil %}
            {% for name in names.sort %}
              {% name = name.id.stringify.camelcase.downcase %}
              {% if name =~ /\*\w+\*/ %}
                when .includes?({{name[1..-2]}}) then {{format}}
              {% elsif name.starts_with? "*" %}
                when .ends_with?({{name[1..-1]}}) then {{format}}
              {% elsif name.ends_with? "*" %}
                when .starts_with?({{name[0..-2]}}) then {{format}}
              {% else %}
                when .==({{name}}) then {{format}}
              {% end %}
            {% end %}
          {% end %}
          end
        {% end %}
      end

      def extnames : Array(String)
        {% begin %}
          case self
          {% for type in FORMAT_TYPES %}
            {% if extnames = type.annotation(RegisterFormat)[:ext] %}
              when {{type.constant("FORMAT_NAME").id}}
                {{extnames}}
            {% end %}
          {% end %}
          else
            [] of String
          end
        {% end %}
      end
    end
  end
end
