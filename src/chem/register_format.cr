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
end

# Gather, check and annotate types registering a format
macro finished
  {%
    formats = [] of TypeNode
    format_table = {} of TypeNode => Hash(String, Array(Tuple(TypeNode, Def)))

    # recursively gather annotated types
    nodes = [@top_level]
    nodes.each do |node|
      formats << node if node.annotation(Chem::RegisterFormat)
      node.constants.map { |c| node.constant(c) }.each do |c|
        nodes << c if c.is_a?(TypeNode) && (c.class? || c.struct? || c.module?)
      end
    end

    # Maps format name to format type
    format_name_table = {} of String => TypeNode
    # Maps extension to format type
    ext_table = {} of String => TypeNode
    # Maps file pattern (without *) to format type
    name_table = {} of String => TypeNode
  %}
  {% for ftype in formats %}
    {%
      ann = ftype.annotation(Chem::RegisterFormat)
      class_methods = ftype.class.methods.select(&.visibility.==(:public))
      format_name = ftype.name.split("::")[-1].id
      format_slug = format_name.downcase.id

      # Checks for duplicate format name
      if other = format_name_table[format_name]
        ann.raise "Format #{format_name} in #{ftype} is registered to #{other}"
      end
      format_name_table[format_name] = ftype

      # Checks for extension collisions
      (ann[:ext] || [] of Nil).each do |ext|
        if other = ext_table[ext]
          ann.raise "Extension #{ext.id} in #{ftype} is registered to #{other}"
        end
        ext_table[ext] = ftype
      end

      # Checks for file pattern collisions
      (ann[:names] || [] of Nil).each do |pattern|
        if other = name_table[pattern]
          ann.raise "File pattern #{pattern.id} in #{ftype} is registered to #{other}"
        end
        name_table[pattern] = ftype
      end

      # Validate that format module has at least one read or write method
      reads_or_writes = class_methods.any? { |m| m.name.starts_with?("read") || m.name == "write" }
      ann.raise "Format module must define at least one of: read, read_all, read_info, write" unless reads_or_writes
    %}

    # Generate `.from_*` methods on readable types
    {% for method in class_methods.select(&.name.starts_with?("read")).reject(&.name.==("read_all")) %}
      {%
        method.raise "Read method must have a return type" unless method.return_type

        rtype = method.return_type.resolve? ||
                method.return_type.id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
                method.return_type.resolve
        args = method.args

        format_table[rtype] = format_table[rtype] || {} of String => Array(Tuple(TypeNode, Def))
        format_table[rtype]["read"] = format_table[rtype]["read"] || [] of Tuple(TypeNode, Def)
        format_table[rtype]["read"] << {ftype, method}

        open_type = rtype
        keyword = "module" if open_type.module?
        keyword = "class" if open_type.class?
        keyword = "struct" if open_type.struct?
      %}
      {{keyword.id}} {{open_type}}
        def self.from_{{format_slug}}({{args.splat}}) : self
          {{ftype}}.{{method.name.id}}({{args.map(&.internal_name).splat}})
        end
      end
    {% end %}

    # Generate `Array.from_*` methods for readable types
    {% for method in class_methods.select(&.name.==("read_all")) %}
      {%
        rtype = method.return_type
        method.raise "Read method must have a return type" unless rtype
        returns_array = rtype.is_a?(Generic) && rtype.name.stringify == "Array"
        method.raise "Read method must return an array" unless returns_array

        rtype = rtype.type_vars[0].resolve? ||
                rtype.type_vars[0].id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
                rtype.type_vars[0].resolve
        args = method.args

        format_table[rtype] = format_table[rtype] || {} of String => Array(Tuple(TypeNode, Def))
        format_table[rtype]["read_multi"] = format_table[rtype]["read_multi"] || [] of Tuple(TypeNode, Def)
        format_table[rtype]["read_multi"] << {ftype, method}
      %}
      class Array(T)
        def self.from_{{format_slug}}({{args.splat}}) : self
          \{% if @type.type_vars[0] <= {{rtype}} %}
            {{ftype}}.read_all({{args.map(&.internal_name).splat}})
          \{% else %}
            \{% raise "undefined method '.from_{{format_slug}}' for #{@type}.class" %}
          \{% end %}
        end
      end
    {% end %}

    # Generate `#to_*` methods on writable types
    {% for method in class_methods.select(&.name.==("write")) %}
      {%
        args = method.args
        method.raise "Write method must have at least two arguments" unless args.size >= 2
        tres = args[1].restriction
        method.raise "Write method must have a type restriction on the second argument" unless tres
      %}

      {% for restype in tres.is_a?(Union) ? tres.types : [tres] %}
        {%
          if restype.is_a?(Generic)
            is_supported = %w(Array Enumerable Indexable Iterable Iterator Slice).includes?(restype.name.stringify)
            tres.raise "Generic type restriction #{tres} is not supported in the write method. \
                        Use standard collection types such as Array or Enumerable." unless is_supported

            wtype = restype.type_vars[0].resolve? ||
                    restype.type_vars[0].id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
                    restype.type_vars[0].resolve

            format_table[wtype] = format_table[wtype] || {} of String => Array(Tuple(TypeNode, Def))
            format_table[wtype]["write_multi"] = format_table[wtype]["write_multi"] || [] of Tuple(TypeNode, Def)
            format_table[wtype]["write_multi"] << {ftype, method, restype.name}

            open_type = "#{restype.name}(T)"
            keyword = {"Array" => "class", "Slice" => "struct"}[restype.name.stringify] || "module"
          else
            wtype = restype.resolve? ||
                    restype.id.split("::").reduce(Chem) { |type, name| type.constant(name) } ||
                    restype.resolve

            format_table[wtype] = format_table[wtype] || {} of String => Array(Tuple(TypeNode, Def))
            format_table[wtype]["write"] = format_table[wtype]["write"] || [] of Tuple(TypeNode, Def)
            format_table[wtype]["write"] << {ftype, method}

            open_type = wtype
            keyword = "module" if open_type.module?
            keyword = "class" if open_type.class?
            keyword = "struct" if open_type.struct?
          end
        %}
        {{keyword.id}} {{open_type.id}}
          def to_{{format_slug}}({{args[0]}}, {{args[2..].splat}}) : Nil
            {{ftype}}.write({{args[0].internal_name}}, self, {{args[2..].map(&.internal_name).splat}})
          end

          def to_{{format_slug}}({{args[2..].splat}}) : String
            String.build do |io|
              to_{{format_slug}}(io, {{args[2..].map(&.internal_name).splat}})
            end
          end
        end
      {% end %}
    {% end %}
  {% end %}

  # Generate `.read` and `#write` methods on readable/writable types
  {% for open_type, format_info in format_table %}
    {%
      keyword = "module" if open_type.module?
      keyword = "class" if open_type.class?
      keyword = "struct" if open_type.struct?
    %}
    {{keyword.id}} {{open_type}}
      {% if format_info["read"] %}
        {% for format_tuple in format_info["read"] %}
          {% ftype, method = format_tuple %}

          def self.read(input : IO | Path | String, format : {{ftype}}.class) : self
            {{ftype}}.{{method.name.id}}(input)
          end
        {% end %}

        # FIXME: Make it compile time error. Should raise if format is not registered or format is incompatible with open_type. Better create an override with the other formats, and leave this as a fallback.
        def self.read(input : IO | Path | String, format) : self
          raise ArgumentError.new("#{format} format cannot read #{self}")
        end

        def self.read(path : IO | Path | String) : self
          read path, Chem.guess_format(path, self)
        end
      {% end %}

      {% if format_info["write"] %}
        {% for format_tuple in format_info["write"] %}
          {% ftype, method = format_tuple %}

          def write(output : IO | Path | String, format : {{ftype}}.class) : Nil
            {{ftype}}.{{method.name.id}}(output, self)
          end
        {% end %}

        # FIXME: Make it compile time error. Should raise if format is not registered or format is incompatible with open_type. Better create an override with the other formats, and leave this as a fallback.
        def write(output : IO | Path | String, format) : Nil
          raise ArgumentError.new("#{format} format cannot write #{self}")
        end

        def write(path : IO | Path | String) : Nil
          write path, Chem.guess_format(path, self.class)
        end
      {% end %}
    end
  {% end %}

  # Generate `Array.read` methods for readable types
  {%
    array_format_table = format_table.to_a
      .select { |(_, format_info)| format_info["read_multi"] }
      .map do |(type, format_info)|
        format_info["read_multi"].map do |(ftype, method)|
          {type, ftype, method}
        end
      end
      .reduce([] of Tuple(TypeNode, TypeNode, Def)) do |acc, format_tuples|
        format_tuples.each { |format_tuple| acc << format_tuple }
        acc
      end
  %}
  {% if array_format_table.size > 0 %}
    class Array(T)
      {% for format_tuple in array_format_table %}
        {% type, ftype, method = format_tuple %}
        def self.read(input : IO | Path | String, format : {{ftype}}.class) : self
          \{% if @type.type_vars[0] <= {{type}} %}
            {{ftype}}.read_all(input)
          \{% else %}
            \{% raise "undefined method 'read' for #{@type}.class" %}
          \{% end %}
        end
      {% end %}

      # FIXME: Make it compile time error. Should raise if format is not registered or format is incompatible with open_type. Better create an override with the other formats, and leave this as a fallback.
      def self.read(input : IO | Path | String, format : U.class) : self forall U
        raise ArgumentError.new("#{format.name.split("::").last} format cannot read #{self}")
      end

      # Returns the entries encoded in the specified file. The file format
      # is chosen based on the filename (see `Chem.guess_format`).
      # Raises `ArgumentError` if the file format cannot be determined.
      def self.read(path : Path | String) : self
        # FIXME: should pass T, not self
        read(path, Chem.guess_format(path, self))
      end
    end
  {% end %}

  # Generate `Array#write` methods for writable types
  {%
    array_format_table = format_table.to_a
      .select { |(_, format_info)| format_info["write_multi"] }
      .map do |(type, format_info)|
        format_info["write_multi"].map do |(ftype, method, container_type)|
          {type, ftype, method, container_type}
        end
      end
      .reduce([] of Tuple(TypeNode, TypeNode, Def, MacroId)) do |acc, format_tuples|
        format_tuples.each { |format_tuple| acc << format_tuple }
        acc
      end
  %}
  {% if array_format_table.size > 0 %}
    class Array(T)
      {% for format_tuple in array_format_table %}
        {% type, ftype, method, container_type = format_tuple %}
        def write(output : IO | Path | String, format : {{ftype}}.class) : Nil
          \{% if @type.type_vars[0] <= {{type}} %}
            {{ftype}}.write(output, self)
          \{% else %}
            \{% raise "undefined method 'write' for #{@type}" %}
          \{% end %}
        end
      {% end %}

      # FIXME: Make it compile time error. Should raise if format is not registered or format is incompatible with open_type. Better create an override with the other formats, and leave this as a fallback.
      def write(output : IO | Path | String, format : U.class) : Nil forall U
        raise ArgumentError.new("#{format.name.split("::").last} format cannot write #{self.class}")
      end

      # Writes the elements to the specified file. The file format is chosen
      # based on the filename (see `Chem.guess_format`). Raises
      # `ArgumentError` if the file format cannot be determined.
      def write(path : Path | String) : Nil
        write path, Chem.guess_format(path, self.class)
      end
    end
  {% end %}

  # Returns the format module for *path* based on its filename, or `nil`
  # if unknown. File stem matching via `File.match?` is case-sensitive
  # but extension matching is not.
  def Chem.guess_format?(path : Path | String)
    path = Path[path]
    stem = path.stem
    ext = path.extension.downcase
    {% for ftype in formats %}
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
  {% for ftype in formats %}
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
  # FIXME: add a list of all readable/writable types
  def Chem.guess_format(path : Path | String, type : T.class) : NoReturn forall T
    \{% raise "No format registered for #{T}. Use one of the readable/writable types." %}
  end
end
