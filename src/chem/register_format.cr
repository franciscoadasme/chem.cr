module Chem
  # Registers a file format.
  #
  # The annotated type provides the implementation of a *file format*
  # that encodes an *encoded type*. The *file format* is determined from
  # the annotated type's name, where the last component of the fully
  # qualified name is used (e.g., `Baz` for `Foo::Bar::Baz`). An entry
  # of the same name will be added to the `Format` enum, where the
  # declared extensions and file patterns will be associated with the
  # corresponding file format. This annotation accepts the following
  # named arguments:
  #
  # - **ext**: an array of extensions (including leading dot).
  # - **names**: an array of file patterns. File patterns can include
  #   wildcards (`"*"`) to denote either prefix (e.g., `"Foo*"`), suffix
  #   (e.g., `"*Bar"`), or both (e.g., `"*Baz*"`). Refer to
  #   `File.match?` for details.
  # - **reader**: reader class name. Defaults to "Reader".
  # - **writer**: writer class name. Defaults to "Writer".
  #
  # The ability to read or write is determined by the declaration of
  # reader and writer classes, respectively, which must include the
  # `FormatReader`, `FormatWriter` and other related mixins when
  # appropriate. The *encoded type* is dictated by the type variable of
  # the included mixins. The `FormatReader::Headed` and
  # `FormatReader::Attached` provides interfaces to read additional
  # information into custom objects.
  #
  # Convenience read (`.from_*` and `.read`) and write (`#to_*` and
  # `#write`) methods will be generated on the *encoded types* during
  # compilation time using the type information of the included mixins
  # in the reader and writer classes. Types declared by the
  # `FormatReader::Headed` and `FormatReader::Attached` are also
  # considered *encoded types*. Additionally, convenience read and write
  # methods will be generated on `Array` for file formats that can hold
  # multiple entries, which are declared via the
  # `FormatReader::MultiEntry` and `FormatWriter::MultiEntry` mixins.
  #
  # ### Example
  #
  # The following code registers the `Foo` format associated with the
  # `Chem::Foo` module, which provides read and write capabilities of
  # `A` via the `Reader` and `Writer` classes, respectively. Both
  # declare that the `Foo` format can hold multiple entries via the
  # corresponding `MultiEntry` mixins. The reader class also provides
  # support for reading the header information into a `B` instance and
  # reading secondary information into a `C` instance.
  #
  # ```
  # record A
  # record B
  # record C
  #
  # @[Chem::RegisterFormat(ext: %w(.foo), names: %w(foo_*))]
  # module Foo
  #   class Reader
  #     include FormatReader(A)
  #     include FormatReader::MultiEntry(A)
  #     include FormatReader::Headed(B)
  #     include FormatReader::Attached(C)
  #
  #     protected def decode_attached : C
  #       C.new
  #     end
  #
  #     protected def decode_entry : A
  #       A.new
  #     end
  #
  #     protected def decode_headed : B
  #       B.new
  #     end
  #   end
  #
  #   class Writer
  #     include FormatWriter(A)
  #     include FormatWriter::MultiEntry(A)
  #
  #     def encode_entry(frame : A) : Nil; end
  #   end
  # end
  # ```
  #
  # The convenience `A.from_foo` and `A.read` methods are generated
  # during compilation time to create an `A` instance from an IO or file
  # using the `Foo` file format. Additionally, the file format can be
  # guessed from the filename.
  #
  # ```
  # # static read methods (can forward arguments to Foo::Reader)
  # A.from_foo(IO::Memory.new) # => A()
  # A.from_foo("a.foo")        # => A()
  #
  # # dynamic read methods (format is detected on runtime; no arguments)
  # A.read(IO::Memory.new, Foo) # => A()
  # A.read("a.foo", Foo)        # => A()
  # A.read("a.foo")             # => A()
  # ```
  #
  # The above methods are also created on the types representing the
  # header (`B`) and attached (`C`) types. This is convenient since one
  # does not to worry about if `X` is either the encoded type, header or
  # attached type to be read from a `Foo` file.
  #
  # Similar to the read methods, `A.to_foo` and `A.write` are generated
  # to write an `A` instance to an IO or file using the `Foo` file
  # format.
  #
  # ```
  # # static read methods (can forward arguments to Foo::Writer)
  # A.new.to_foo                 # returns a string representation
  # A.new.to_foo(IO::Memory.new) # writes to an IO
  # A.new.to_foo("a.foo")        # writes to a file
  #
  # # dynamic read methods (format is detected on runtime; no arguments)
  # A.new.write(IO::Memory.new, Foo)
  # A.new.write("a.foo", Foo)
  # A.new.write("a.foo")
  # ```
  #
  # These methods are not generated for header (`B`) and attached (`C`)
  # types however, because these cannot produce a valid `Foo` file by
  # themselves. If a header/attached object is required to write a valid
  # file, it should be declared as a required argument in the writer
  # (see `Cube::Writer` or `VASP::Chgcar::Writer`).
  #
  # Since `Foo::Reader` and `Foo::Writer` reads and writes multiple
  # entries (indicated by the corresponding `MultiEntry` mixins), the
  # `.from_foo`, `.read`, `#to_foo`, and `#write` methods are also
  # generated in `Array` during compilation time.
  #
  # ```
  # Array(A).from_foo(IO::Memory.new)  # => [Foo(), ...]
  # Array(A).from_foo("a.foo")         # => [Foo(), ...]
  # Array(A).read(IO::Memory.new, Foo) # => [Foo(), ...]
  # # and other overloads
  #
  # Array(A).new.to_foo                    # returns a string representation
  # Array(A).new.to_foo(IO::Memory.new)    # writes to an IO
  # Array(A).new.to_foo("a.foo")           # writes to a file
  # Array(A).new.write IO::Memory.new, Foo # writes to an IO
  # # and other overloads
  # ```
  #
  # Calling any of these methods on an array of unsupported types will
  # produce a missing method error during compilation.
  #
  # Refer to the implementations of the supported file formats (e.g.,
  # `PDB` and `XYZ`) for real examples.
  #
  # NOTE: Method overloading may not work as expected in some cases.
  # If two methods with the same name and required arguments (may have different optional arguments), only the last overload will be taken into account and trying to calling the first one will result in a missing method error during compilation.
  # Example:
  # ```
  # # Both methods require input, but baz is optional
  # module Foo
  #   def self.read(input : String, baz : Bool = false)
  #     "1"
  #   end
  #
  #   def self.read(input : String)
  #     "2"
  #   end
  # end
  #
  # Foo.read "foo"            # => "2"
  # Foo.read "foo", baz: true # Missing method error
  #
  # # Setting baz as required makes the two overloads different
  # module Foo
  #   def self.read(input : String, baz : Bool)
  #     "1"
  #   end
  #
  #   def self.read(input : String)
  #     "2"
  #   end
  # end
  #
  # Foo.read "foo"            # => "2"
  # Foo.read "foo", baz: true # => "1"
  # ```
  annotation RegisterFormat; end

  # :nodoc:
  FORMAT_TYPES = [] of Nil
end

macro finished
  # Gather, check and annotate types registering a format

  # gather annotated types under the Chem module
  {% nodes = [@top_level] %}
  {% for node in nodes %}
    {% Chem::FORMAT_TYPES << node if node.annotation(Chem::RegisterFormat) %}
    {% for c in node.constants.map { |c| node.constant(c) } %}
      {% nodes << c if c.is_a?(TypeNode) && (c.class? || c.struct? || c.module?) %}
    {% end %}
  {% end %}

  # Maps format name to format type
  {% format_map = {} of String => TypeNode %}
  # Maps extension to format type
  {% ext_map = {} of String => TypeNode %}
  # Maps file pattern (without *) to format type
  {% name_map = {} of String => TypeNode %}
  {% for ftype in Chem::FORMAT_TYPES %}
    {% ann = ftype.annotation(Chem::RegisterFormat) %}

    # Checks for duplicate format name
    {% format = ftype.name.split("::")[-1].id %}
    {% method_name = format.downcase %}
    {% if type = format_map[format] %}
      {% ann.raise "Format #{format} in #{ftype} is registered to #{type}" %}
    {% end %}
    {% format_map[format] = ftype %}

    # Checks for extension collisions
    {% for ext in (ann[:ext] || [] of Nil) %}
      {% if type = ext_map[ext] %}
        {% ann.raise "Extension #{ext.id} in #{ftype} is registered to #{type}" %}
      {% end %}
      {% ext_map[ext] = ftype %}
    {% end %}

    # Checks for file pattern collisions
    {% for name_spec in (ann[:names] || [] of Nil) %}
      {% key = name_spec.tr("*", "").camelcase.underscore %}
      {% if type = name_map[key] %}
        {% ann.raise "File pattern #{name_spec.id} in #{ftype} is \
                      registered to #{type}" %}
      {% end %}
      {% name_map[key] = ftype %}
    {% end %}

    # Validate that format module has at least one read or write method
    {% class_methods = ftype.class.methods.map(&.name.stringify) %}
    {% has_read = class_methods.includes?("read") %}
    {% has_read_all = class_methods.includes?("read_all") %}
    {% has_read_info = class_methods.includes?("read_info") %}
    {% has_read_structure = class_methods.includes?("read_structure") %}
    {% has_write = class_methods.includes?("write") %}
    {% has_any = has_read || has_read_all || has_read_info || has_read_structure || has_write %}
    {% ann.raise "Format module must define at least one of: read, read_all, read_info, write" unless has_any %}

    {% keyword = "module" if ftype.module? %}
    {% keyword = "class" if ftype.class? %}
    {% keyword = "struct" if ftype.struct? %}
    {{keyword.id}} {{ftype}}
      # :nodoc:
      FORMAT_NAME = "{{format}}"
      # :nodoc:
      FORMAT_METHOD_NAME = "{{method_name}}"

      def self.format_name : String
        FORMAT_NAME
      end
    end
  {% end %}
end

macro finished
  # Generate methods on encoded types from module methods

  {% for ftype in Chem::FORMAT_TYPES %}
    {% method_name = ftype.constant("FORMAT_METHOD_NAME").id %}
    {% class_methods = ftype.class.methods %}

    {% for read_method in class_methods.select(&.name.==("read")) %}
      {% if read_method.return_type %}
        {% etype = read_method.return_type.resolve? ||
                   read_method.return_type.id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
                   read_info_method.return_type.resolve %}
        {% args = read_method.args %}
        {% keyword = "module" if etype.module? %}
        {% keyword = "class" if etype.class? %}
        {% keyword = "struct" if etype.struct? %}
        {{keyword.id}} {{etype}}
          def self.from_{{method_name}}(
            input : IO | Path | String{% for arg, i in args %}{% if i > 0 %}, {{arg}}{% end %}{% end %}
          ) : self
            {{ftype}}.read(input{% for arg, i in args %}{% if i > 0 %}, {{arg.internal_name}}{% end %}{% end %})
          end
        end
      {% end %}
    {% end %}

    {% read_info_method = class_methods.find(&.name.==("read_info")) %}
    {% if read_info_method && read_info_method.return_type %}
      {% etype = read_info_method.return_type.resolve? ||
                 read_info_method.return_type.id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
                 read_info_method.return_type.resolve %}
      {% args = read_info_method.args %}
      {% keyword = "module" if etype.module? %}
      {% keyword = "class" if etype.class? %}
      {% keyword = "struct" if etype.struct? %}
      {{keyword.id}} {{etype}}
        def self.from_{{method_name}}(
          input : IO | Path | String{% for arg, i in args %}{% if i > 0 %}, {{arg}}{% end %}{% end %}
        ) : self
          {{ftype}}.read_info(input{% for arg, i in args %}{% if i > 0 %}, {{arg.internal_name}}{% end %}{% end %})
        end
      end
    {% end %}

    {% read_all_method = class_methods.find(&.name.==("read_all")) %}
    {% if read_all_method && read_all_method.return_type %}
      {% ret = read_all_method.return_type %}
      {% if ret.is_a?(Generic) && ret.name.stringify == "Array" %}
        {% etype = ret.type_vars[0].resolve? ||
                   ret.type_vars[0].id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
                   ret.type_vars[0].resolve %}
        {% args = read_all_method.args %}
        class Array(T)
          def self.from_{{method_name}}(
            input : IO | Path | String{% for arg, i in args %}{% if i > 0 %}, {{arg}}{% end %}{% end %}
          ) : self
            \{% if @type.type_vars[0] <= {{etype}} %}
              {{ftype}}.read_all(input{% for arg, i in args %}{% if i > 0 %}, {{arg.internal_name}}{% end %}{% end %})
            \{% else %}
              \{% raise "undefined method '.from_{{method_name}}' for #{@type}.class" %}
            \{% end %}
          end
        end
      {% end %}
    {% end %}

    {% write_methods = class_methods.select(&.name.==("write")) %}
    {% for write_method in write_methods %}
      {% if write_method.args.size >= 2 %}
        {% obj_arg = write_method.args[1] %}
        {% if obj_restriction = obj_arg.restriction %}
          {% obj_types = obj_restriction.is_a?(Union) ? obj_restriction.types : [obj_restriction] %}
          {% for obj_type in obj_types %}
            {% if obj_type.is_a?(Generic) && obj_type.name.stringify == "Enumerable" %}
              {% etype = obj_type.type_vars[0] %}
              {% args = write_method.args %}
              class Array(T)
                def to_{{method_name}}(
                  output : IO | Path | String{% for arg, i in args %}{% if i > 1 %}, {{arg}}{% end %}{% end %}
                ) : Nil
                  {{ftype}}.write(output, self{% for arg, i in args %}{% if i > 1 %}, {{arg.internal_name}}{% end %}{% end %})
                end

                def to_{{method_name}}(
                  {% for arg, i in args %}
                    {% if i > 1 %}{{arg}}{% if i < args.size - 1 %},{% end %}
                    {% end %}
                  {% end %}
                ) : String
                  String.build do |io|
                    {{ftype}}.write(io, self{% for arg, i in args %}{% if i > 1 %}, {{arg.internal_name}}{% end %}{% end %})
                  end
                end
              end
            {% else %}
              {% etype = obj_type.resolve? ||
                         obj_type.id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
                         obj_type.resolve %}
              {% args = write_method.args %}
              {% keyword = "module" if etype.module? %}
              {% keyword = "class" if etype.class? %}
              {% keyword = "struct" if etype.struct? %}
              {{keyword.id}} {{etype}}
                def to_{{method_name}}(
                  {% for arg, i in args %}
                    {% if i > 1 %}{{arg}}{% if i < args.size - 1 %},{% end %}
                    {% end %}
                  {% end %}
                ) : String
                  String.build do |io|
                    {{ftype}}.write(io, self{% for arg, i in args %}{% if i > 1 %}, {{arg.internal_name}}{% end %}{% end %})
                  end
                end

                def to_{{method_name}}(
                  output : IO | Path | String{% for arg, i in args %}{% if i > 1 %}, {{arg}}{% end %}{% end %}
                ) : Nil
                  {{ftype}}.write(output, self{% for arg, i in args %}{% if i > 1 %}, {{arg.internal_name}}{% end %}{% end %})
                end
              end
            {% end %}
          {% end %}
        {% end %}
      {% end %}
    {% end %}
  {% end %}

  # Generate read(input, format) and write(output, format) for encoded types
  # Each entry: (etype, ftype, read_method_name)
  {% read_type_formats = [] of Tuple(TypeNode, TypeNode, String) %}
  {% write_type_formats = [] of Tuple(TypeNode, TypeNode) %}
  {% for ftype in Chem::FORMAT_TYPES %}
    {% class_methods = ftype.class.methods %}
    {% read_m = class_methods.find(&.name.==("read")) %}
    {% if read_m && read_m.return_type %}
      {% read_type_formats << {read_m.return_type, ftype, "read"} %}
    {% end %}
    {% read_info_m = class_methods.find(&.name.==("read_info")) %}
    {% if read_info_m && read_info_m.return_type %}
      {% read_type_formats << {read_info_m.return_type, ftype, "read_info"} %}
    {% end %}
    {% read_structure_m = class_methods.find(&.name.==("read_structure")) %}
    {% if read_structure_m && read_structure_m.return_type %}
      {% read_type_formats << {read_structure_m.return_type, ftype, "read_structure"} %}
    {% end %}
    {% for write_m in class_methods.select(&.name.==("write")) %}
      {% if write_m.args.size >= 2 %}
        {% obj_restriction = write_m.args[1].restriction %}
        {% if obj_restriction %}
          {% obj_types = obj_restriction.is_a?(Union) ? obj_restriction.types : [obj_restriction] %}
          {% for obj_type in obj_types %}
            {% if !obj_type.is_a?(Generic) || obj_type.name.stringify != "Enumerable" %}
              {% write_type_formats << {obj_type, ftype} %}
            {% end %}
          {% end %}
        {% end %}
      {% end %}
    {% end %}
  {% end %}
  {% read_types_seen = [] of TypeNode %}
  {% for pair in read_type_formats %}
    {% etype = pair[0].resolve? ||
               pair[0].id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
               pair[0].resolve %}
    {% ftype = pair[1] %}
    {% method_name = pair[2] %}
    {% is_first = !read_types_seen.includes?(etype) %}
    {% read_types_seen << etype if is_first %}
    {% keyword = "module" if etype.module? %}
    {% keyword = "class" if etype.class? %}
    {% keyword = "struct" if etype.struct? %}
    {{keyword.id}} {{etype}}
      {% if is_first %}
      def self.read(path : Path | String) : self
        read path, Chem.guess_format(path, self)
      end
      {% end %}
      def self.read(input : IO | Path | String, format : {{ftype}}.class) : self
        {{ftype}}.{{method_name.id}}(input)
      end
    end
  {% end %}
  {% for pair in read_type_formats %}
    {% etype = pair[0].resolve? ||
               pair[0].id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
               pair[0].resolve %}
    {% keyword = "module" if etype.module? %}
    {% keyword = "class" if etype.class? %}
    {% keyword = "struct" if etype.struct? %}
    {{keyword.id}} {{etype}}
      def self.read(input : IO | Path | String, format) : self
        raise ArgumentError.new("#{format} format is write only")
      end
    end
  {% end %}
  {% write_types_seen = [] of TypeNode %}
  {% for pair in write_type_formats %}
    {% etype = pair[0].resolve? ||
               pair[0].id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
               pair[0].resolve %}
    {% ftype = pair[1] %}
    {% is_first = !write_types_seen.includes?(etype) %}
    {% write_types_seen << etype if is_first %}
    {% keyword = "module" if etype.module? %}
    {% keyword = "class" if etype.class? %}
    {% keyword = "struct" if etype.struct? %}
    {{keyword.id}} {{etype}}
      {% if is_first %}
      def write(path : Path | String) : Nil
        write path, Chem.guess_format(path, self.class)
      end
      {% end %}
      def write(output : IO | Path | String, format : {{ftype}}.class) : Nil
        {{ftype}}.write(output, self)
      end
    end
  {% end %}
  {% for pair in write_type_formats %}
    {% etype = pair[0].resolve? ||
               pair[0].id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
               pair[0].resolve %}
    {% keyword = "module" if etype.module? %}
    {% keyword = "class" if etype.class? %}
    {% keyword = "struct" if etype.struct? %}
    {{keyword.id}} {{etype}}
      def write(output : IO | Path | String, format) : Nil
        raise ArgumentError.new("#{format.format_name} format cannot write #{self.class}")
      end
    end
  {% end %}

  class Array(T)
    # Returns the entries encoded in the specified file. The file format
    # is chosen based on the filename (see `Chem.guess_format`).
    # Raises `ArgumentError` if the file format cannot be determined.
    def self.read(path : Path | String) : self
      read(path, Chem.guess_format(path, self))
    end

    # Returns the entries encoded in the specified file using *format*.
    # Raises `ArgumentError` if *format* cannot read the element type or
    # it is write only.
    # Accepts any format module (e.g. return value of guess_format(path))
    {% read_all_formats = [] of TypeNode %}
    {% read_all_etypes = [] of TypeNode %}
    {% for ftype in Chem::FORMAT_TYPES %}
      {% read_all_m = ftype.class.methods.find(&.name.==("read_all")) %}
      {% if read_all_m && read_all_m.return_type %}
        {% ret = read_all_m.return_type %}
        {% if ret.is_a?(Generic) && ret.name.stringify == "Array" %}
          {% read_all_formats << ftype %}
          {% read_all_etypes << ret.type_vars[0] %}
        {% end %}
      {% end %}
    {% end %}
    {% if read_all_etypes.size == 0 %}
      def self.read(input : IO | Path | String, format) : self
        \{% raise "undefined method 'read' for #{@type}.class" %}
      end
    {% else %}
      {% for ftype, i in read_all_formats %}
        {% etype = read_all_etypes[i].resolve? ||
                   read_all_etypes[i].id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
                   read_all_etypes[i].resolve %}
        def self.read(input : IO | Path | String, format : {{ftype}}.class) : self
          \{% if @type.type_vars[0] <= {{etype}} %}
            {{ftype}}.read_all(input)
          \{% else %}
            \{% raise "undefined method 'read' for #{@type}.class" %}
          \{% end %}
        end
      {% end %}
      def self.read(input : IO | Path | String, format : {{Chem::FORMAT_TYPES.map { |x| "#{x}.class" }.join(" | ").id}}) : self
        case format
        {% for ftype in read_all_formats %}
        when {{ftype}}
          {{ftype}}.read_all(input)
        {% end %}
        else
          raise ArgumentError.new("#{format.format_name} format cannot read #{self}")
        end
      end
      def self.read(input : IO | Path | String, format) : self
        raise ArgumentError.new("#{format.format_name} format cannot read #{self}")
      end
    {% end %}

    # Writes the elements to the specified file. The file format is chosen
    # based on the filename (see `Chem.guess_format`). Raises
    # `ArgumentError` if the file format cannot be determined.
    def write(path : Path | String) : Nil
      write path, Chem.guess_format(path, self.class)
    end

    # Writes the elements to *output* using *format*. Raises
    # `ArgumentError` if *format* cannot write the element type or it is
    # read only.
    # Accepts any format module (e.g. return value of guess_format(path))
    {% write_enum_formats = [] of TypeNode %}
    {% write_enum_etypes = [] of TypeNode %}
    {% for ftype in Chem::FORMAT_TYPES %}
      {% for write_m in ftype.class.methods.select(&.name.==("write")) %}
        {% if write_m.args.size >= 2 %}
          {% obj_restriction = write_m.args[1].restriction %}
          {% if obj_restriction %}
            {% obj_types = obj_restriction.is_a?(Union) ? obj_restriction.types : [obj_restriction] %}
            {% for obj_type in obj_types %}
              {% if obj_type.is_a?(Generic) && obj_type.name.stringify == "Enumerable" %}
                {% write_enum_formats << ftype %}
                {% write_enum_etypes << obj_type.type_vars[0] %}
              {% end %}
            {% end %}
          {% end %}
        {% end %}
      {% end %}
    {% end %}
    {% if write_enum_etypes.size == 0 %}
      def write(output : IO | Path | String, format) : Nil
        \{% raise "undefined method 'write' for #{@type}" %}
      end
    {% else %}
      {% for ftype, i in write_enum_formats %}
        {% etype = write_enum_etypes[i].resolve? ||
                   write_enum_etypes[i].id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
                   write_enum_etypes[i].resolve %}
        def write(output : IO | Path | String, format : {{ftype}}.class) : Nil
          \{% if @type.type_vars[0] <= {{etype}} %}
            {{ftype}}.write(output, self)
          \{% else %}
            \{% raise "undefined method 'write' for #{@type}" %}
          \{% end %}
        end
      {% end %}
      def write(output : IO | Path | String, format) : Nil
        raise ArgumentError.new("#{format.format_name} format cannot write #{self.class}")
      end
    {% end %}
  end
end

macro finished
  # Returns the format module for *path* based on its filename, or `nil`
  # if unknown. File stem matching via `File.match?` is case-sensitive 
  # but extension matching is not.
  def Chem.guess_format?(path : Path | String)
    path = Path[path]
    stem = path.stem
    ext = path.extension.downcase
    {% for ftype in Chem::FORMAT_TYPES %}
      {% if exts = ftype.annotation(Chem::RegisterFormat)[:ext] %}
        return {{ftype}} if {{{exts.splat}}}.includes?(ext)
      {% end %}
      {% if names = ftype.annotation(Chem::RegisterFormat)[:names] %}
        return {{ftype}} if {{{names.splat}}}.any? { |pattern| File.match?(pattern, stem) }
      {% end %}
    {% end %}
  end

  # Returns the format module for *path* based on its filename. File
  # stem matching via `File.match?` is case-sensitive but extension
  # matching is not. Raises ArgumentError if the format cannot be
  # determined.
  def Chem.guess_format(path : Path | String)
    guess_format?(path) || raise ArgumentError.new("File format not found for #{path}")
  end

  # Build (type_key, is_array, formats) - type_key is etype for single, etype for Array(etype)
  {% type_format_pairs = [] of Tuple(String, Bool, TypeNode) %}
  {% for ftype in Chem::FORMAT_TYPES %}
    {% class_methods = ftype.class.methods %}
    {% read_m = class_methods.find(&.name.==("read")) %}
    {% if read_m && read_m.return_type %}
      {% etype = read_m.return_type.resolve? ||
                 read_m.return_type.id.split("::").reduce(Chem) { |t, n| t.constant(n) } ||
                 read_m.return_type.resolve %}
      {% type_format_pairs << {etype.stringify, false, ftype} %}
    {% end %}
    {% read_info_m = class_methods.find(&.name.==("read_info")) %}
    {% if read_info_m && read_info_m.return_type %}
      {% etype = read_info_m.return_type.resolve? ||
                 read_info_m.return_type.id.split("::").reduce(Chem) { |t, n| t.constant(n) } ||
                 read_info_m.return_type.resolve %}
      {% type_format_pairs << {etype.stringify, false, ftype} %}
    {% end %}
    {% read_structure_m = class_methods.find(&.name.==("read_structure")) %}
    {% if read_structure_m && read_structure_m.return_type %}
      {% etype = read_structure_m.return_type.resolve? ||
                 read_structure_m.return_type.id.split("::").reduce(Chem) { |t, n| t.constant(n) } ||
                 read_structure_m.return_type.resolve %}
      {% type_format_pairs << {etype.stringify, false, ftype} %}
    {% end %}
    {% read_all_m = class_methods.find(&.name.==("read_all")) %}
    {% if read_all_m && read_all_m.return_type %}
      {% ret = read_all_m.return_type %}
      {% if ret.is_a?(Generic) && ret.name.stringify == "Array" %}
        {% etype = ret.type_vars[0].resolve? ||
                   ret.type_vars[0].id.split("::").reduce(Chem) { |t, n| t.constant(n) } ||
                   ret.type_vars[0].resolve %}
        {% type_format_pairs << {"Array(#{etype})", true, ftype} %}
      {% end %}
    {% end %}
    {% for write_m in class_methods.select(&.name.==("write")) %}
      {% if write_m.args.size >= 2 %}
        {% obj_restriction = write_m.args[1].restriction %}
        {% if obj_restriction %}
          {% obj_types = obj_restriction.is_a?(Union) ? obj_restriction.types : [obj_restriction] %}
          {% for obj_type in obj_types %}
            {% if obj_type.is_a?(Generic) && obj_type.name.stringify == "Enumerable" %}
              {% etype = obj_type.type_vars[0].resolve? ||
                         obj_type.type_vars[0].id.split("::").reduce(Chem) { |t, n| t.constant(n) } ||
                         obj_type.type_vars[0].resolve %}
              {% type_format_pairs << {"Array(#{etype})", true, ftype} %}
            {% else %}
              {% etype = obj_type.resolve? ||
                         obj_type.id.split("::").reduce(Chem) { |t, n| t.constant(n) } ||
                         obj_type.resolve %}
              {% type_format_pairs << {etype.stringify, false, ftype} %}
            {% end %}
          {% end %}
        {% end %}
      {% end %}
    {% end %}
  {% end %}

  # Group by type key and collect unique formats (manual - no group_by in macros)
  {% seen_keys = [] of String %}
  {% for pair in type_format_pairs %}
    {% type_key = pair[0] %}
    {% unless seen_keys.includes?(type_key) %}
      {% seen_keys << type_key %}
      {% formats = [] of TypeNode %}
      {% for p in type_format_pairs %}
        {% formats << p[2] if p[0] == type_key %}
      {% end %}
      {% formats = formats.uniq %}
      {% if formats.size > 0 %}
        {% format_union = formats.map { |f| "#{f}.class" }.join(" | ").id %}
        def Chem.guess_format(path : Path | String, type : {{type_key.id}}.class) : {{format_union}}
          (guess_format?(path) || raise ArgumentError.new("File format not found for #{path}")).as({{format_union}})
        end
      {% end %}
    {% end %}
  {% end %}

  # Wildcard: raises at compile time for unsupported types
  def Chem.guess_format(path : Path | String, type)
    \{% raise "guess_format does not support type #{type} - use one of the encoded types" %}
  end
end
