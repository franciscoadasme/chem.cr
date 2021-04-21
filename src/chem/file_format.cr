module Chem
  macro finished
    # gather annotated types
    {% types = [] of TypeNode %}
    {% nodes = [Chem] %}
    {% for node in nodes %}
      {% types << node if node.annotation(FileType) %}
      {% for c in node.constants.map { |c| node.constant(c) } %}
        {% nodes << c if c.is_a?(TypeNode) && (c.class? || c.struct? || c.module?) %}
      {% end %}
    {% end %}

    {% file_types = {} of MacroId => Annotation %}
    {% for type in types %}
      {% ann = type.annotation(FileType) %}
      # last component of the fully qualified type name (Foo::Bar::Baz => Baz)
      {% format = type.name.split("::")[-1].id %}
      {% file_types[format] = ann %}
    {% end %}

    # List of the available file formats.
    #
    # This enum is populated based on the file formats declared on the
    # classes annotated with the `FileType` annotation. Methods that
    # deals with extensions and file names uses the information declared
    # in the corresponding annotations.
    enum FileFormat
      {% for format in file_types.keys.sort %}
        {{format.id}}
      {% end %}

      {% for format in file_types.keys.sort %}
        def {{format.id.downcase}}? : Bool
          self == {{format}}
        end
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
          {% for format, ann in file_types %}
            {% if ext = ann[:ext] %}
              when {{ext.map { |ext| ".#{ext.downcase.id}" }.splat}}
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
        {% begin %}
          case stem.camelcase.downcase
          {% for format, ann in file_types %}
            {% if names = ann[:names] %}
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
          {% end %}
          end
        {% end %}
      end

      def extnames : Array(String)
        {% begin %}
          case self
          {% for format, ann in file_types %}
            {% if ext = ann[:ext] %}
              when {{format}}
                {{ext.map { |ext| ".#{ext.id}" }}}
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
