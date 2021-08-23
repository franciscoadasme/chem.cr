module Chem
  macro finished
    # List of the registered file formats.
    #
    # This enum is populated based on the `RegisterFormat` annotation.
    # Methods that deals with extensions and file patterns uses the
    # information declared in the annotations.
    #
    # ```
    # @[Chem::RegisterFormat(ext: %w(.jpg .jpeg .jpe)), names: %w(IMG*)]
    # module Chem::JPEG; end
    #
    # @[Chem::RegisterFormat(ext: %w(.tiff .tif))]
    # module Chem::TIFF; end
    #
    # Chem::Format.names                 # => ["JPEG", "TIFF"]
    # Chem::Format::JPEG                 # => JPEG
    # Chem::Format::JPEG.extnames        # => [".jpg", ".jpeg", ".jpe"]
    # Chem::Format::JPEG.file_patterns   # => ["IMG*"]
    # Chem::Format::TIFF.extnames        # => [".tiff", ".tif"]
    # Chem::Format::TIFF.file_patterns   # => []
    #
    # Chem::Format.from_ext("foo.jpg")   # => JPEG
    # Chem::Format.from_ext("foo.tiff")  # => TIFF
    # Chem::Format.from_stem("IMG_2015") # => JPEG
    # ```
    enum Format
      {% for ftype in FORMAT_TYPES.sort_by(&.constant("FORMAT_NAME")) %}
        {% format = ftype.constant("FORMAT_NAME") %}
        # The {{format.id}} format implemented by `{{ftype}}`.
        {{format.id}}
      {% end %}

      {% for ftype in FORMAT_TYPES %}
        {% format = ftype.constant("FORMAT_NAME").id %}
        # Returns `true` if the member is the `{{format}}` format.
        def {{ftype.constant("FORMAT_METHOD_NAME").id}}? : Bool
          self == {{format}}
        end
      {% end %}

      # Returns the file format registered to the file extension, or
      # raises `ArgumentError` otherwise.
      #
      # ```
      # @[Chem::RegisterFormat(ext: %w(.jpg .jpeg .jpe))]
      # module Chem::JPEG; end
      #
      # Chem::Format.from_ext(".jpg")  # => JPEG
      # Chem::Format.from_ext(".JPG")  # => JPEG
      # Chem::Format.from_ext(".jpeg") # => JPEG
      # Chem::Format.from_ext(".jpe")  # => JPEG
      # Chem::Format.from_ext(".txt")  # raises ArgumentError
      # ```
      #
      # NOTE: It performs a case-insensitive search so .jpg and .JPG
      # return the same.
      def self.from_ext(extname : String) : self
        from_ext?(extname) || raise ArgumentError.new "File format not found for #{extname}"
      end

      # Returns the file format registered to the file extension, or
      # `nil` otherwise.
      #
      # ```
      # @[Chem::RegisterFormat(ext: %w(.jpg .jpeg .jpe))]
      # module Chem::JPEG; end
      #
      # Chem::Format.from_ext?(".jpg")  # => JPEG
      # Chem::Format.from_ext?(".JPG")  # => JPEG
      # Chem::Format.from_ext?(".jpeg") # => JPEG
      # Chem::Format.from_ext?(".jpe")  # => JPEG
      # Chem::Format.from_ext?(".txt")  # => nil
      # ```
      #
      # NOTE: It performs a case-insensitive search so .jpg and .JPG
      # return the same.
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

      # Returns the file format associated with *filename*, or raises
      # `ArgumentError` otherwise.
      #
      # It first looks up the file format associated with the extension
      # of *filename* via the `.from_ext?` method. If the latter returns
      # `nil`, then it executes a case-insensitive search with the stem
      # of *filename* via `.from_stem?`.
      #
      # ```
      # @[Chem::RegisterFormat(ext: %w(.jpg .jpeg .jpe), names: %w(IMG*))]
      # module Chem::JPEG; end
      #
      # Chem::Format.from_filename("foo.jpg")      # => JPEG
      # Chem::Format.from_filename("foo.JPG")      # => JPEG
      # Chem::Format.from_filename("IMG_2314.jpg") # => JPEG
      # Chem::Format.from_filename("IMG_2314.png") # => JPEG
      # Chem::Format.from_filename("IMG_2314")     # => JPEG
      # Chem::Format.from_filename("img_2314")     # => JPEG
      # Chem::Format.from_filename("img2314")      # => JPEG
      # Chem::Format.from_filename("foo")          # raises ArgumentError
      # ```
      def self.from_filename(filename : Path | String) : self
        format = from_filename? filename
        format || raise ArgumentError.new "File format not found for #{filename}"
      end

      # Returns the file format associated with *filename*, or `nil`
      # otherwise.
      #
      # It first looks up the file format associated with the extension
      # of *filename* via the `.from_ext?` method. If the latter returns
      # `nil`, then it executes a case-insensitive search with the stem
      # of *filename* via `.from_stem?`.
      #
      # ```
      # @[Chem::RegisterFormat(ext: %w(.jpg .jpeg .jpe), names: %w(IMG*))]
      # module Chem::JPEG; end
      #
      # Chem::Format.from_filename?("foo.jpg")      # => JPEG
      # Chem::Format.from_filename?("foo.JPG")      # => JPEG
      # Chem::Format.from_filename?("IMG_2314.jpg") # => JPEG
      # Chem::Format.from_filename?("IMG_2314.png") # => JPEG
      # Chem::Format.from_filename?("IMG_2314")     # => JPEG
      # Chem::Format.from_filename?("img_2314")     # => JPEG
      # Chem::Format.from_filename?("img2314")      # => JPEG
      # Chem::Format.from_filename?("foo")          # => nil
      # ```
      def self.from_filename?(filename : Path | String) : self?
        filename = Path[filename] unless filename.is_a?(Path)
        extname = filename.extension
        from_ext?(extname) || from_stem?(filename.basename(extname))
      end

      # Returns the file format that matches the file stem, or raises
      # `ArgumentError` otherwise.
      #
      # The file stem is matched against the file patterns registered by
      # the file formats until one match is found. File patterns can
      # contain valid filename characters and the `*` wildcard, which
      # matches an unlimited number of arbitrary characters:
      #
      # - `"c*"` matches file stems beginning with `c`.
      # - `"*c"` matches file stems ending with `c`.
      # - `"*c*"` matches file stems that have `c` in them (including at
      #   the beginning or end).
      #
      # ```
      # @[Chem::RegisterFormat(names: %w(IMG*))]
      # module Chem::JPEG; end
      # ...
      #
      # Chem::Format.from_stem("IMG_2314") # => JPEG
      # Chem::Format.from_stem("img_2314") # => JPEG
      # Chem::Format.from_stem("img2314")  # => JPEG
      # Chem::Format.from_stem("himg")     # raises ArgumentError
      # Chem::Format.from_stem("foo")      # raises ArgumentError
      # ```
      #
      # NOTE: The comparison is made using `String#camelcase` and
      # `String#downcase`, so the file pattern `FooBar` will match
      # `FOOBAR`, `FooBar`, `foobar`, `FOO_BAR` and `foo_bar`.
      def self.from_stem(stem : Path | String) : self
        from_stem?(stem) || raise ArgumentError.new "File format not found for #{stem}"
      end

      # Returns the file format that matches the file stem, or `nil`
      # otherwise.
      #
      # The file stem is matched against the file patterns registered by
      # the file formats until one match is found. File patterns can
      # contain valid filename characters and the `*` wildcard, which
      # matches an unlimited number of arbitrary characters:
      #
      # - `"c*"` matches file stems beginning with `c`.
      # - `"*c"` matches file stems ending with `c`.
      # - `"*c*"` matches file stems that have `c` in them (including at
      #   the beginning or end).
      #
      # ```
      # @[Chem::RegisterFormat(names: %w(IMG*))]
      # module Chem::JPEG; end
      #
      # Chem::Format.from_stem?("IMG_2314") # => JPEG
      # Chem::Format.from_stem?("img_2314") # => JPEG
      # Chem::Format.from_stem?("img2314")  # => JPEG
      # Chem::Format.from_stem?("himg")     # => nil
      # Chem::Format.from_stem?("foo")      # => nil
      # ```
      #
      # NOTE: The comparison is made using `String#camelcase` and
      # `String#downcase`, so the file pattern `FooBar` will match
      # `FOOBAR`, `FooBar`, `foobar`, `FOO_BAR` and `foo_bar`.
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

      # Returns `true` if the format can write an instance of *type*.
      #
      # ```
      # Chem::Format::XYZ.encodes?(Chem::AtomCollection)      # => true
      # Chem::Format::XYZ.encodes?(Chem::Structure)           # => true
      # Chem::Format::XYZ.encodes?(Array(Chem::Structure))    # => true
      # Chem::Format::Poscar.encodes?(Chem::AtomCollection)   # => false
      # Chem::Format::Poscar.encodes?(Chem::Structure)        # => true
      # Chem::Format::Poscar.encodes?(Array(Chem::Structure)) # => false
      # Chem::Format::XYZ.encodes?(Int32)                     # => false
      # Chem::Format::XYZ.encodes?(Array(Int32))              # => false
      # ```
      def encodes?(type : Array(T).class) : Bool forall T
        {% begin %}
          case self
          {% for ftype in FORMAT_TYPES %}
            in {{ftype.constant("FORMAT_NAME").id}}
              {% if (etype = ftype.constant("WRITE_TYPE")) %}
                {% writer = ftype.constant("WRITER") %}
                T <= {{etype}} && {{writer}} < FormatWriter::MultiEntry
              {% else %}
                false
              {% end %}
          {% end %}
          end
        {% end %}
      end

      # :ditto:
      def encodes?(type : T.class) : Bool forall T
        {% begin %}
          case self
          {% for ftype in FORMAT_TYPES %}
            in {{ftype.constant("FORMAT_NAME").id}}
              {% if etype = ftype.constant("WRITE_TYPE") %}
                type <= {{etype}}
              {% else %}
                false
              {% end %}
          {% end %}
          end
        {% end %}
      end

      # Returns the file extensions associated with the file format.
      #
      # ```
      # @[Chem::RegisterFormat(ext: %w(.jpg .jpeg .jpe))]
      # module Chem::JPEG; end
      #
      # Chem::Format::JPEG.extnames # => [".jpg", ".jpeg", ".jpe"]
      # ```
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

      # Returns the file patterns associated with the file format.
      #
      # ```
      # @[Chem::RegisterFormat(names: %w(IMG*))]
      # module Chem::JPEG; end
      #
      # Chem::Format::JPEG.file_patterns # => ["IMG*"]
      # ```
      def file_patterns : Array(String)
        {% begin %}
          case self
          {% for type in FORMAT_TYPES %}
            {% if names = type.annotation(RegisterFormat)[:names] %}
              when {{type.constant("FORMAT_NAME").id}}
                {{names}}
            {% end %}
          {% end %}
          else
            [] of String
          end
        {% end %}
      end

      {% format_types = FORMAT_TYPES.select(&.constant("READ_TYPE")) %}
      {% for etype in format_types.map(&.constant("READ_TYPE").resolve).uniq %}
        # Returns the reader associated with the format. Raises
        # `ArgumentError` if the format does not decode *type* or it is
        # write only.
        #
        # ```
        # Chem::Format::XYZ.reader(Chem::Structure)           # => Chem::XYZ::Reader
        # Chem::Format::DX.reader(Chem::Spatial::Grid)        # => Chem::DX::Reader
        # Chem::Format::XYZ.reader(Array(Chem::Structure))    # => Chem::XYZ::Reader
        # Chem::Format::DX.reader(Array(Chem::Spatial::Grid)) # raises ArgumentError
        # Chem::Format::VMD.reader(Chem::Structure)           # raises ArgumentError
        # Chem::Format::XYZ.reader(Int32)                     # raises ArgumentError
        # ```
        def reader(type : {{etype}}.class)
          {% begin %}
            case self
            {% for ftype in format_types %}
              when {{ftype.constant("FORMAT_NAME").id}}
                {% if ftype.constant("READ_TYPE").resolve >= etype %}
                  {{ftype.constant("READER")}}
                {% else %}
                  raise ArgumentError.new("#{self} format cannot read #{type}")
                {% end %}
            {% end %}
            else
              raise ArgumentError.new("#{self} format is write only")
            end
          {% end %}
        end
      {% end %}

      {% for etype in format_types
                        .select(&.constant("READER").resolve.<=(FormatReader::MultiEntry))
                        .map(&.constant("READ_TYPE").resolve).uniq %}
        # :ditto:
        def reader(type : Array({{etype}}).class)
          {% begin %}
            case self
            {% for ftype in format_types %}
              when {{ftype.constant("FORMAT_NAME").id}}
                {% if ftype.constant("READ_TYPE").resolve >= etype &&
                        ftype.constant("READER").resolve <= FormatReader::MultiEntry %}
                  {{ftype.constant("READER")}}
                {% else %}
                  raise ArgumentError.new("#{self} format cannot read #{type}")
                {% end %}
            {% end %}
            else
              raise ArgumentError.new("#{self} format is write only")
            end
          {% end %}
        end
      {% end %}

      {% format_types = FORMAT_TYPES.select(&.constant("WRITE_TYPE")) %}
      {% for etype in format_types.map(&.constant("WRITE_TYPE").resolve).uniq %}
        # Returns the writer associated with the format. Raises
        # `ArgumentError` if the format does not encode *type* or it is
        # read only.
        #
        # ```
        # Chem::Format::XYZ.writer(Chem::Structure)           # => Chem::XYZ::Writer
        # Chem::Format::DX.writer(Chem::Spatial::Grid)        # => Chem::DX::Writer
        # Chem::Format::XYZ.writer(Array(Chem::Structure))    # => Chem::XYZ::Writer
        # Chem::Format::DX.writer(Array(Chem::Spatial::Grid)) # raises ArgumentError
        # Chem::Format::XYZ.writer(Int32)                     # raises ArgumentError
        # ```
        def writer(type : {{etype}}.class)
          {% begin %}
            case self
            {% for ftype in format_types %}
              when {{ftype.constant("FORMAT_NAME").id}}
                {% if ftype.constant("WRITE_TYPE").resolve >= etype %}
                  {{ftype.constant("WRITER")}}
                {% else %}
                  raise ArgumentError.new("#{self} format cannot write #{type}")
                {% end %}
            {% end %}
            else
              raise ArgumentError.new("#{self} format is read only")
            end
          {% end %}
        end
      {% end %}

      {% for etype in format_types
                        .select(&.constant("WRITER").resolve.<=(FormatWriter::MultiEntry))
                        .map(&.constant("WRITE_TYPE").resolve).uniq %}
        # :ditto:
        def writer(type : Array({{etype}}).class)
          {% begin %}
            case self
            {% for ftype in format_types %}
              when {{ftype.constant("FORMAT_NAME").id}}
                {% if ftype.constant("WRITE_TYPE").resolve >= etype &&
                        ftype.constant("WRITER").resolve <= FormatWriter::MultiEntry %}
                  {{ftype.constant("WRITER")}}
                {% else %}
                  raise ArgumentError.new("#{self} format cannot write #{type}")
                {% end %}
            {% end %}
            else
              raise ArgumentError.new("#{self} format is read only")
            end
          {% end %}
        end
      {% end %}
    end
  end
end
