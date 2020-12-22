module Chem::IO
  # Marks a type to be associated with a file format.
  #
  # An annotated type must provide implementations for either reading or
  # writing, or both, an instance of the *encoded types* from or to an
  # *IO* following the specification of the associated *file format*.
  # The latter is determined from the type's name, where the last
  # component of the fully qualified name is used as the file format
  # (e.g., `Baz` for `Foo::Bar::Baz`) The ability of a type to read or
  # write is determined by the declaration of a reader (includes the
  # `Reader` mixin) and writer (includes the `Writer` mixin) class,
  # respectively.
  #
  # The *encoded types* are dictated by the type variables of the
  # included mixins. A class can declare encoded multiple types by
  # including the reader/writer mixin for every encoded type. This is
  # useful for cases when a file format may encode multiple objects in
  # the same content (e.g., some volumetric data file formats used in
  # computational chemistry also include information of the molecule
  # structure).
  #
  # ```
  # record Point3d, x : Float64, y : Float64, z : Float64
  # record Atom, element : String, coords : Point3d
  # record Frame, title : String, atoms : Array(Atom)
  #
  # @[FileType(ext: %w(foo), names: %w(foo_*))]
  # module Chem::Foo
  #   class Reader
  #     include IO::Reader(Frame)
  #
  #     def read : Frame
  #       n = @io.gets.to_i
  #       title = @io.gets
  #       atoms = Array(Atom).new(n) do
  #         tokens = @io.gets.split
  #         x, y, z = tokens[1..].map(&.to_i)
  #         Atom.new tokens[0], Point3d.new(x, y, z)
  #       end
  #       Frame.new title, atoms
  #     end
  #   end
  #
  #   class Writer
  #     include IO::Writer(Frame)
  #     include IO::Writer(Atom)
  #
  #     def write(frame : Frame) : Nil
  #       @io.puts frame.coords.size
  #       @io.puts frame.title
  #       frame.coords.each do |atom|
  #         write atom
  #       end
  #     end
  #
  #     def write(atom : Atom) : Nil
  #       formatl "%-8s%8.3f%8.3f%8.3f", atom.element, atom.x, atom.y, atom.z
  #     end
  #   end
  # end
  #
  # FileFormat::Foo                      # => Foo
  # FileFormat.from_filename("file.foo") # => Foo
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
  # frame = Frame.from_foo(io)
  # frame.atoms.size # => 9
  # frame.atoms[0]   # => {2.336, 3.448, 7.781}
  # frame.to_foo(io)
  # frame.atoms[0].to_foo(io)
  # ```
  #
  # This annotation accepts the following named arguments:
  #
  # - **ext**: an array of extensions (without leading dot).
  # - **names**: an array of file names. File names can include
  #   wildcards (`"*"`) to denote either prefix (e.g., `"Foo*"`), suffix
  #   (e.g., `"*Bar"`), or both (e.g., `"*Baz*"`).
  # - **reader**: reader class name. Defaults to `"Reader"`.
  # - **writer**: writer class name. Defaults to `"Writer"`.
  #
  # The `FileFormat` enum is populated based on the information of this
  # annotation, where extensions and file names are associated with the
  # corresponding file format. It is also used to generate read
  # (`#from_*`) and write (`#to_*`) methods for the encoded types when
  # appropiate.
  #
  # NOTE: annotated types must be declared within the `Chem` module,
  # otherwise they won't be recognized.
  annotation FileType; end

  macro finished
    # gather annotated types under the Chem module
    {% types = [] of TypeNode %}
    {% nodes = [Chem] %}
    {% for node in nodes %}
      {% types << node if node.annotation(FileType) %}
      {% for c in node.constants.map { |c| node.constant(c) } %}
        {% nodes << c if c.is_a?(TypeNode) && (c.class? || c.struct? || c.module?) %}
      {% end %}
    {% end %}
    {% file_types = types.map &.annotation(FileType) %}

    # annotated type => canonical format (without Chem module)
    {% canonical_formats = {} of TypeNode => MacroId %}
    # encoded types gathered from the type vars of the included modules
    {% encoded_types = [] of TypeNode %}
    # annotated type => format (last component of the type name)
    {% formats = {} of TypeNode => MacroId %}
    # encoded_type => associated read types
    {% read_table = {} of TypeNode => ArrayLiteral(TypeNode) %}
    # annotated type => reader class (declared within the annotated type)
    {% reader_table = {} of TypeNode => TypeNode %}
    # annotated type => extension
    {% type_by_ext = {} of String => MacroId %}
    # annotated type => file name
    {% type_by_name = {} of String => MacroId %}
    # encoded_type => associated writing types
    {% write_table = {} of TypeNode => ArrayLiteral(TypeNode) %}
    # annotated type => writer class (declared within the annotated type)
    {% writer_table = {} of TypeNode => TypeNode %}

    # check annotations
    {% for annotated_type in types %}
      {% ann = annotated_type.annotation(FileType) %}

      # check unique format (last component of the type name, Foo::Bar::Baz => Baz)
      {% format = annotated_type.name.split("::")[-1].id %}
      {% if other = formats.keys.find { |t| formats[t] == format } %}
        {% raise "#{annotated_type} declares file format #{format}, " \
                 "but it is already declared by #{other}" %}
      {% end %}
      {% formats[annotated_type] = format %}
      # remove the Chem module from the fully qualified name
      {% canonical_formats[annotated_type] = annotated_type.name.gsub(/^\w+::/, "").id %}

      # check duplicate extensions
      {% if extnames = ann[:ext] %}
        {% if ext = extnames.find { |ext| type_by_ext[ext] } %}
          {% raise ".#{ext.id} extension declared in FileType annotation " \
                   "for #{annotated_type} is already associated with file " \
                   "format #{other} via #{type_by_ext[ext]}" %}
          {% type_by_ext[ext] = annotated_type %}
        {% end %}
      {% end %}

      # check duplicate file names
      {% if names = ann[:names] %}
        {% names = names.map { |n| n.tr("*", "").camelcase.underscore } %}
        {% if name = names.find { |n| type_by_name[n] } %}
          {% raise "Filename #{name} declared in FileType annotation" \
                   "for #{annotated_type} is already associated with file " \
                   "format #{other} via #{type_by_name[name]}" %}
          {% type_by_name[name] = annotated_type %}
        {% end %}
      {% end %}

      # gather encoded types for reading
      {% n_types = 0 %}
      {% if reader = annotated_type.constant(ann[:reader] || "Reader") %}
        # encoded types are detected from the type vars from the
        # included modules (include Reader(Structure) => Structure)
        {% for type in reader.resolve.ancestors.select(&.<(Reader)).map(&.type_vars[0]) %}
          {% unless read_table[type] %}
            {% read_table[type] = [] of TypeNode %}
          {% end %}
          {% encoded_types << type %}
          {% read_table[type] << annotated_type %}
          {% n_types += 1 %}
        {% end %}
        {% reader_table[annotated_type] = reader %}
      {% end %}

      # gather encoded types for writing
      {% if writer = annotated_type.constant(ann[:writer] || "Writer") %}
        # encoded types are detected from the type vars from the
        # included modules (include Writer(Structure) => Structure)
        {% for type in writer.resolve.ancestors.select(&.<(Writer)).map(&.type_vars[0]) %}
          {% for type in type.union_types %}
            {% unless write_table[type] %}
              {% write_table[type] = [] of TypeNode %}
            {% end %}
            {% encoded_types << type %}
            {% write_table[type] << annotated_type %}
            {% n_types += 1 %}
          {% end %}
        {% end %}
        {% writer_table[annotated_type] = writer %}
      {% end %}

      # check readers/writers
      {% if n_types == 0 %}
        {% raise "#{annotated_type} does not declare readers or writers" %}
      {% end %}
    {% end %}

    # generate read/write methods on encoded types
    {% for encoded_type in encoded_types.uniq %}
      {% keyword = "module" if encoded_type.module? %}
      {% keyword = "class" if encoded_type.class? %}
      {% keyword = "struct" if encoded_type.struct? %}

      {{keyword.id}} ::{{encoded_type.id}}
        {% if types = read_table[encoded_type] %}
          {% for type in types %}
            {% format = formats[type].id.downcase %}
            {% canonical_format = canonical_formats[type] %}

            {% reader = reader_table[type] %}
            # remove the Chem module from the fully qualified name
            {% canonical_reader = reader.stringify.gsub(/^\w+::/, "").id %}

            # Returns the object encoded in *input* using the
            # `{{canonical_format}}` file format. Arguments are fowarded
            # to `{{canonical_reader}}`.
            {% if reader < MultiReader %}
              #
              # This method returns the first entry only. Use
              # `Array#from_{{format.id}}` or `{{canonical_reader}}` to
              # get multiple entries instead.
            {% end %}
            def self.from_{{format.id}}(input : ::IO | Path | String,
                                        *args,
                                        **options) : self
              {{reader}}.open(input, *args, **options) do |reader|
                reader.read
              end
            end
          {% end %}

          {% read_formats = types.map { |t| "`#{canonical_formats[t]}`".id } %}

          # Returns the object encoded in the specified file. The file
          # format is chosen based on the filename (refer to
          # `IO::FileFormat#from_filename`).
          #
          # The supported file formats are {{read_formats.splat}}. Use
          # `#from_*` methods to customize how the object is decoded in
          # the corresponding file format.
          #
          # Raises `ArgumentError` when the file format couldn't be
          # determined.
          def self.read(path : Path | String) : self
            read path, IO::FileFormat.from_filename(path)
          end

          # Returns the object encoded in the specified file using the
          # given file format.
          #
          # The supported file formats are {{read_formats.splat}}. Use
          # `#from_*` methods to customize how the object is decoded in
          # the corresponding file format.
          #
          # Raises `ArgumentError` when *format* is invalid.
          def self.read(input : ::IO | Path | String,
                        format : IO::FileFormat | String) : self
            format = IO::FileFormat.parse format if format.is_a?(String)
            {% begin %}
              case format
              {% for reader in types %}
                {% format = formats[reader].id.downcase %}
                when .{{format.id}}?
                  from_{{format.id}} input
              {% end %}
              else
                raise ArgumentError.new "#{format} does not encode {{encoded_type}}"
              end
            {% end %}
          end
        {% end %}

        {% if types = write_table[encoded_type] %}
          {% for type in types %}
            {% format = formats[type].id.downcase %}
            {% canonical_format = canonical_formats[type] %}

            {% writer = writer_table[type] %}
            # remove the Chem module from the fully qualified name
            {% canonical_writer = writer.stringify.gsub(/^\w+::/, "").id %}

            # Returns a string representation of this object encoded using
            # the `{{canonical_format}}` file format. Arguments are
            # fowarded to `{{canonical_writer}}`.
            def to_{{format.id}}(*args, **options) : String
              String.build do |io|
                to_{{format.id}} io, *args, **options
              end
            end

            # Writes this object to *output* using the
            # `{{canonical_format}}` file format. Arguments are fowarded
            # to `{{canonical_writer}}`.
            def to_{{format.id}}(output : ::IO | Path | String, *args, **options) : Nil
              {{writer}}.open(output, *args, **options) do |writer|
                writer.write self
              end
            end
          {% end %}

          {% write_formats = types.map { |t| "`#{canonical_formats[t]}`".id } %}

          # Writes this object to the specified file. The file format is
          # chosen based on the filename (refer to
          # `IO::FileFormat#from_filename`).
          #
          # The supported file formats are {{write_formats.splat}}. Use
          # `#to_*` methods to customize how the object is written in
          # the corresponding file format.
          #
          # Raises `ArgumentError` when the file format couldn't be
          # determined.
          def write(path : Path | String) : Nil
            write path, IO::FileFormat.from_filename(path)
          end

          # Writes this object to *output* using the given file format.
          #
          # The supported file formats are {{write_formats.splat}}. Use
          # `#to_*` methods to customize how the object is written in
          # the corresponding file format.
          #
          # Raises `ArgumentError` when *format* is invalid.
          def write(output : ::IO | Path | String, format : IO::FileFormat | String) : Nil
            format = IO::FileFormat.parse format if format.is_a?(String)
            {% begin %}
              case format
              {% for writer in types %}
                {% format = formats[writer].id.downcase %}
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

      {% if types = read_table[encoded_type] %}
        {% for type in types %}
          {% if (reader = reader_table[type]) && reader < MultiReader %}
            {% format = formats[type].id.downcase %}

            class ::Array(T)
              # Creates a new array with the entries encoded in *input*
              # using the `{{type}}` file format. Arguments are fowarded
              # to `{{reader}}`.
              #
              # NOTE: Only works for `{{encoded_type}}`.
              def self.from_{{format.id}}(input : ::IO | Path | String,
                      *args,
                      **options) : self
                {{reader}}.open(input, *args, **options) do |reader|
                  ary = [] of T
                  reader.each { |ele| ary << ele }
                  ary
                end
              end

              # Creates a new array with the entries encoded in *input*
              # using the `{{type}}` file format. Entries listed in
              # *indexes* are read only. Arguments are fowarded to
              # `{{reader}}`.
              #
              # NOTE: Only works for `{{encoded_type}}`.
              def self.from_{{format.id}}(input : ::IO | Path | String,
                                          indexes : Enumerable(Int),
                                          *args,
                                          **options) : self
                {{reader}}.open(input, *args, **options) do |reader|
                  ary = [] of T
                  reader.each(indexes) { |ele| ary << ele }
                  ary
                end
              end
            end
          {% end %}
        {% end %}
      {% end %}
    {% end %}
  end
end
