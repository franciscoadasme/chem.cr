module Chem::IO
  # Marks a class to be associated with a file format.
  #
  # An annotated class must either read or write an instance of the
  # *encoded type* from or to an IO following the specification of the
  # associated *file format*. The ability of a class to read or write is
  # dictated by whether it includes the `Reader` or `Writer` modules,
  # respectively.
  #
  # This annotation accepts the following named arguments:
  #
  # - **encoded** (required): name (unquoted) that resolves into a valid
  #   type
  # - **format** (required): file format (in camel case and unquoted)
  # - **ext**: an array of extensions (without leading dot)
  # - **names**: an array of file names. File names can include
  #   wildcards (`"*"`) to denote either prefix (e.g., `"Foo*"`), suffix
  #   (e.g., `"*Bar"`), or both (e.g., `"*Baz*"`)
  #
  # The `FileFormat` enum is populated based on the information of this
  # annotation, where extensions and file names are associated with the
  # corresponding file format. It is also used to generate read
  # (`#from_*`) and write (`#to_*`) methods for the encoded types when
  # appropiate.
  #
  # ```
  # alias Point3d = Tuple(Float64, Float64, Float64)
  # record Frame, coords : Array(Point3d)
  #
  # @[FileType(format: XYZ, encoded: Frame, ext: %w(.xyz))]
  # class FrameReader
  #   include IO::Reader(Frame)
  #
  #   def read : Frame
  #     n = @io.gets.to_i
  #     title = @io.gets
  #     coords = Array(Point3d).new(n) do
  #       x, y, z = @io.gets.split[1..].map(&.to_i)
  #       Point3d.new(x, y, z)
  #     end
  #     Frame.new title, coords
  #   end
  # end
  #
  # FileFormat::XYZ                # => XYZ
  # FileFormat.from_ext("foo.xyz") # => XYZ
  #
  # io = IO::Memory.new <<-EOS
  #   9
  #   Three waters
  #   O   2.336   3.448   7.781
  #   H   1.446   3.485   7.315
  #   H   2.977   2.940   7.234
  #   O  11.776  11.590   8.510
  #   H  12.756  11.588   8.379
  #   H  11.395  11.031   7.787
  #   O   6.015  11.234   7.771
  #   H   6.440  12.040   7.394
  #   H   6.738  10.850   8.321
  #   EOS
  #
  # frame = Frame.from_xyz(io)
  # frame.coords.size # => 9
  # frame.coords[0]   # => {2.336, 3.448, 7.781}
  # ```
  annotation FileType; end

  macro finished
    {% readers = Reader.includers.select &.annotation(FileType) %}
    {% writers = Writer.includers.select &.annotation(FileType) %}
    {% types = readers + writers %}
    {% file_types = types.map &.annotation(IO::FileType) %}

    # check missing annotation arguments
    {% format_by_ext = {} of String => MacroId %}
    {% format_by_name = {} of String => MacroId %}
    {% type_by_ext = {} of String => MacroId %}
    {% type_by_name = {} of String => MacroId %}
    {% encoded_types = [] of TypeNode %}
    {% for t in types %}
      {% ann = t.annotation(FileType) %}

      {% type = (type = ann[:encoded]) && type.resolve? %}
      {% raise "`encoded` is missing in FileType annotation for #{t}" unless type %}
      {% encoded_types << type unless encoded_types.includes?(type) %}

      {% format = ann[:format].id %}
      {% raise "`format` is missing in FileType annotation for #{t}" unless format %}

      {% if extnames = ann[:ext] %}
        {% for ext in extnames %}
          {% if (other = format_by_ext[ext]) && other != format %}
            {% raise ".#{ext.id} extension declared in FileType annotation for #{t} " \
                     "is already associated with file format #{other} " \
                     "via #{type_by_ext[ext]}" %}
          {% end %}
          {% format_by_ext[ext] = format %}
          {% type_by_ext[ext] = t %}
        {% end %}
      {% elsif names = ann[:names] %}
        {% for name in names %}
          {% key = name.tr("*", "").camelcase.underscore %}
          {% if (other = format_by_name[key]) && other != format %}
            {% raise "Filename #{name} declared in FileType annotation for #{t} " \
                     "is already associated with file format #{other} " \
                     "via #{type_by_name[name]}" %}
          {% end %}
          {% format_by_name[key] = format %}
          {% type_by_name[key] = t %}
        {% end %}
      {% else %}
        {% raise "`ext` and `names` are missing in FileType annotation for #{t}" %}
      {% end %}
    {% end %}

    # check duplicate file formats
    {% file_formats = file_types.map(&.[:format].id).uniq.sort %}
    {% for format in file_formats %}
      {% for ary in [readers, writers] %}
        {% ary = ary.select &.annotation(IO::FileType)[:format].id.==(format) %}
        {% if ary.size > 1 %}
          {% raise "#{format} file format in FileType annotation for #{t} " \
                   "is already associated with #{ary[0]}" %}
        {% end %}
      {% end %}
    {% end %}

    # generate read/write methods on encoded types
    {% for encoded_type in encoded_types %}
      {% keyword = "module" if encoded_type.module? %}
      {% keyword = "class" if encoded_type.class? %}
      {% keyword = "struct" if encoded_type.struct? %}
      {% providers = types.select do |t|
           encoded_type <= t.annotation(IO::FileType)[:encoded].resolve
         end %}

      {{keyword.id}} ::{{encoded_type.id}}
        {% for type in providers %}
          {% canonical_format = type.annotation(IO::FileType)[:format] %}
          {% format = canonical_format.id.downcase %}
          {% canonical_type = type.stringify.gsub(/^\w+::/, "").id %}

          {% if type < Reader %}
            # Returns the object encoded in *input* using the
            # `{{canonical_format}}` file format. Arguments are fowarded
            # to `{{canonical_type}}`.
            {% if type < MultiReader %}
              #
              # This method returns the first entry only. Use
              # `Array#from_{{format.id}}` or `{{canonical_type}}` to
              # get multiple entries instead.
            {% end %}
            def self.from_{{format.id}}(input : ::IO | Path | String,
                                        *args,
                                        **options) : self
              {{type}}.open(input, *args, **options) do |reader|
                reader.read
              end
            end
          {% end %}

          {% if type < MultiReader %}
            class ::Array(T)
              # Creates a new array with the entries encoded in *input*
              # using the `{{canonical_format}}` file format. Arguments
              # are fowarded to `{{canonical_type}}`.
              #
              # NOTE: Only works for `{{encoded_type}}`.
              def self.from_{{format.id}}(input : ::IO | Path | String,
                      *args,
                      **options) : self
                {{type}}.open(input, *args, **options) do |reader|
                  ary = [] of T
                  reader.each { |ele| ary << ele }
                  ary
                end
              end

              # Creates a new array with the entries encoded in *input*
              # using the `{{canonical_format}}` file format. Entries
              # listed in *indexes* are read only. Arguments are
              # fowarded to `{{canonical_type}}`.
              #
              # NOTE: Only works for `{{encoded_type}}`.
              def self.from_{{format.id}}(input : ::IO | Path | String,
                                          indexes : Enumerable(Int),
                                          *args,
                                          **options) : self
                {{type}}.open(input, *args, **options) do |reader|
                  ary = [] of T
                  reader.each(indexes) { |ele| ary << ele }
                  ary
                end
              end
            end
          {% end %}

          {% if type < Writer %}
            # Returns a string representation of this object encoded
            # using the `{{canonical_format}}` file format. Arguments
            # are fowarded to `{{canonical_type}}`.
            def to_{{format.id}}(*args, **options) : String
              String.build do |io|
                to_{{format.id}} io, *args, **options
              end
            end

            # Writes this object to *output* using the
            # `{{canonical_format}}` file format. Arguments are fowarded
            # to `{{canonical_type}}`.
            def to_{{format.id}}(output : ::IO | Path | String, *args, **options) : Nil
              {{type}}.open(output, *args, **options) do |writer|
                writer.write self
              end
            end
          {% end %}
        {% end %}

        {% unless (readers = providers.select &.<(Reader)).empty? %}
          {% canonical_formats = readers
               .map(&.annotation(IO::FileType)[:format])
               .map { |f| "`#{f}`".id } %}
          # Returns the object encoded in the specified file. The file
          # format is chosen based on the filename (refer to
          # `IO::FileFormat#from_filename`).
          #
          # The supported file formats are {{canonical_formats.splat}}.
          # Use `#from_*` methods to customize how the object is decoded
          # from the corresponding file format.
          #
          # Raises `ArgumentError` when the file format couldn't be
          # determined.
          def self.read(path : Path | String) : self
            read path, IO::FileFormat.from_filename(path)
          end

          # Returns the object encoded in the specified file using the
          # given file format.
          #
          # The supported file formats are {{canonical_formats.splat}}.
          # Use `#from_*` methods to customize how the object is decoded
          # from the corresponding file format.
          #
          # Raises `ArgumentError` when *format* is invalid.
          def self.read(input : ::IO | Path | String,
                        format : IO::FileFormat | String) : self
            format = IO::FileFormat.parse format if format.is_a?(String)
            {% begin %}
              case format
              {% for reader in readers %}
                {% format = reader.annotation(IO::FileType)[:format].id.downcase %}
                when .{{format.id}}?
                  from_{{format.id}} input
              {% end %}
              else
                raise ArgumentError.new "#{format} does not encode {{encoded_type}}"
              end
            {% end %}
          end
        {% end %}

        {% unless (writers = providers.select &.<(Writer)).empty? %}
          {% canonical_formats = writers
               .map(&.annotation(IO::FileType)[:format])
               .map { |f| "`#{f}`".id } %}

          # Writes this object to the specified file. The file format is
          # chosen based on the filename (refer to
          # `IO::FileFormat#from_filename`).
          #
          # The supported file formats are {{canonical_formats.splat}}.
          # Use `#to_*` methods to customize how the object is written
          # in the corresponding file format.
          #
          # Raises `ArgumentError` when the file format couldn't be
          # determined.
          def write(path : Path | String) : Nil
            write path, IO::FileFormat.from_filename(path)
          end

          # Writes this object to *output* using the given file format.
          #
          # The supported file formats are {{canonical_formats.splat}}.
          # Use `#to_*` methods to customize how the object is written
          # in the corresponding file format.
          #
          # Raises `ArgumentError` when *format* is invalid.
          def write(output : ::IO | Path | String, format : IO::FileFormat | String) : Nil
            format = IO::FileFormat.parse format if format.is_a?(String)
            {% begin %}
              case format
              {% for writer in writers %}
                {% format = writer.annotation(IO::FileType)[:format].id.downcase %}
                when .{{format.id}}?
                  to_{{format.id}} output
              {% end %}
              else
                raise ArgumentError.new "#{format} does not encode {{encoded_type}}"
              end
            {% end %}
          end
        {% end %}
      end
    {% end %}
  end
end
