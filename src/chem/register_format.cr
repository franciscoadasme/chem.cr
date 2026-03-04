module Chem
  # Registers a file format.
  #
  # The annotated type provides the implementation of a *file format* that encodes an *encoded type*.
  # The *file format* is determined from the annotated type's name, where the last component of the fully qualified name is used (e.g., `Baz` for `Foo::Bar::Baz`).
  # The declared extensions and file patterns are used for format detection via `Chem.guess_format`.
  #
  # The annotation accepts the following named arguments:
  #
  # - **ext**: an array of extensions (including leading dot).
  # - **names**: an array of file patterns.
  #   The pattern syntax is similar to shell filename globbing and it is evaluated via `File.match?` to match against a filepath.
  #
  # The format module must define at least one of:
  #
  # - `.each`: Must yield each entry in the given input.
  # - `.read`: Must read the next entry from the given input.
  # - `.read_all`: Must read all entries from the given input.
  # - Any other `.read_*` method must read a single entry from the given input.
  #   Useful for formats that include additional information in the header.
  # - `.write`: Must write a single entry to the given output.
  #
  # The *encoded type* is inferred from the type restrictions and return type of the methods, so they must be annotated.
  # The methods must accept an IO as first argument.
  # Use the `define_file_overload` macro to generate overloads that accept `Path | String` instead of `IO`.
  #
  # Convenience read (`.from_*` and `.read`) and write (`#to_*` and `#write`) methods will be generated on the *encoded types* during compilation time using the type information from the methods.
  # Additionally, convenience read and write methods will be generated on `Array` for file formats that can hold multiple entries (indicated by the definition of `.read_all` and `.write(io, Array)`).
  #
  # ### Example
  #
  # The following code registers the `Foo` format matching the `*.foo` and `foo_*` files.
  # The module defines `.each`, `read`, `read_all`, and `write` to read instances of `A` and `Array(A)`, and write `A`, respectively.
  # Additionally, it defines additional read methods for `B` instances.
  #
  # ```
  # record A
  # record B
  #
  # @[Chem::RegisterFormat(ext: %w(.foo), names: %w(foo_*))]
  # module Foo
  #   def self.each(io : IO, & : A ->) : Nil
  #     loop do
  #       yield read(io)
  #     rescue IO::EOFError
  #       break
  #     end
  #   end
  #
  #   def self.read(io : IO) : A
  #     A.new
  #   end
  #
  #   def self.read_all(io : IO) : Array(A)
  #     entries = [] of A
  #     each(io) { |entry| entries << entry }
  #     entries
  #   end
  #
  #   def self.read_info(io : IO) : B
  #     B.new
  #   end
  #
  #   def self.write(io : IO, instance : A) : Nil
  #     # ...
  #   end
  #
  #   def self.write(io : IO, instances : Array(A), info : B) : Nil
  #     # write header based on info
  #     instances.each { |instance| write(io, instance) }
  #   end
  # end
  # ```
  #
  # The convenience `A.from_foo` and `A.read` methods are generated during compilation time to create an `A` instance from an IO or file using the `Foo` file format.
  # Additionally, the file format can be guessed from the filename.
  #
  # ```
  # # static read methods (can forward arguments to Foo.read)
  # A.from_foo(IO::Memory.new) # => A()
  # A.from_foo("a.foo")        # => A()
  #
  # # dynamic read methods (format is detected on runtime; no arguments)
  # A.read(IO::Memory.new, Foo) # => A()
  # A.read("a.foo", Foo)        # => A()
  # A.read("a.foo")             # => A()
  # ```
  #
  # The above methods are also created on the `B` type.
  #
  # Similar to the read methods, `A.to_foo` and `A.write` are generated to write an `A` instance to an IO or file using the `Foo` file format.
  #
  # ```
  # # static read methods (can forward arguments to Foo.write)
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
  # Since `Foo` reads and writes multiple entries (indicated by `.read_all` and `.write(io, Array(A))`), the `.from_foo`, `.read`, `#to_foo`, and `#write` methods are also generated in `Array` during compilation time.
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
  # Calling any of these methods on an array of unsupported types will produce a missing method error during compilation.
  #
  # Refer to the implementations of the supported file formats (e.g., `PDB` and `XYZ`) for real examples.
  #
  # NOTE: Method overloading may not work as expected in some cases.
  # If two methods with the same name and required arguments (may have different optional arguments), only the last overload will be taken into account and trying to calling the first one will result in a missing method error during compilation.
  #
  # Example:
  #
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

      type_parents = ftype.name.split("::").reduce([] of TypeNode) { |acc, name| acc << (acc[-1] || @top_level).constant(name) }
    %}

    # Generate `.from_*` methods on readable types
    {% for method in class_methods.select(&.name.starts_with?("read")).reject(&.name.==("read_all")) %}
      {%
        method.raise "Read method must have a return type" unless method.return_type

        # Resolve the return type relative to the format module
        rtype = method.return_type.resolve?
        if !rtype
          parts = method.return_type.id.split("::")
          rtype = type_parents.map(&.constant(parts[0])).find(&.nil?.!) || method.return_type.resolve # trigger error if not found
          rtype = parts[1..].reduce(rtype) { |type, name| type.constant(name) }
        end
        # FIXME: args should be scoped to the format module as they will be used within the readable/writable type
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

        # Resolve the array's element type relative to the format module
        type_var = rtype.type_vars[0]
        rtype = type_var.resolve?
        if !rtype
          parts = type_var.id.split("::")
          rtype = type_parents.map(&.constant(parts[0])).find(&.nil?.!) || type_var.resolve # trigger error if not found
          rtype = parts[1..].reduce(rtype) { |type, name| type.constant(name) }
        end
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
            # TODO: enforce Array everywhere. there are a few cases where it'd be beneficial to allow other types
            is_supported = %w(Array Enumerable Indexable Iterable Iterator Slice).includes?(restype.name.stringify)
            tres.raise "Generic type restriction #{tres} is not supported in the write method. \
                        Use standard collection types such as Array or Enumerable." unless is_supported

            # Resolve the collection's element type relative to the format module
            type_var = restype.type_vars[0]
            wtype = type_var.resolve?
            if !wtype
              parts = type_var.id.split("::")
              wtype = type_parents.map(&.constant(parts[0])).find(&.nil?.!) || type_var.resolve # trigger error if not found
              wtype = parts[1..].reduce(wtype) { |type, name| type.constant(name) }
            end

            format_table[wtype] = format_table[wtype] || {} of String => Array(Tuple(TypeNode, Def))
            format_table[wtype]["write_multi"] = format_table[wtype]["write_multi"] || [] of Tuple(TypeNode, Def)
            format_table[wtype]["write_multi"] << {ftype, method, restype.name}

            open_type = "#{restype.name}(T)"
            keyword = {"Array" => "class", "Slice" => "struct"}[restype.name.stringify] || "module"
          else
            # Resolve the type restriction relative to the format module
            wtype = restype.resolve?
            if !wtype
              parts = restype.id.split("::")
              wtype = type_parents.map(&.constant(parts[0])).find(&.nil?.!) || restype.resolve # trigger error if not found
              wtype = parts[1..].reduce(wtype) { |type, name| type.constant(name) }
            end

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

  # TODO: Improve docs.

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

  {% for open_type, format_info in format_table %}
    {%
      supported_formats, array_supported_formats = ["", "_multi"].map do |suffix|
        %w(read write).map(&.+(suffix)).reduce([] of TypeNode) do |acc, key|
          format_info[key].each { |(ftype, method)| acc << ftype } if format_info[key]
          acc
        end.sort_by(&.name).uniq
      end
      # TODO: Add support for any collection type. Group format_info by container type.
      supported_format_table = {open_type => supported_formats, "Enumerable(#{open_type})".id => array_supported_formats}
    %}
    {% for tres, supported_formats in supported_format_table %}
      {% if supported_formats.size > 0 %}
        {% format_union = supported_formats.map { |f| "#{f}.class" }.join(" | ").id %}
        # Returns the format compatible with `{{tres}}` based on *path*.
        # Raises `ArgumentError` if the format does not support *type* or cannot be determined.
        #
        # This method effectively narrows down the union of available formats to those compatible with *type*.
        # See `.guess_format?(path)` for more details.
        def Chem.guess_format(path : Path | String, type : {{tres}}.class) : {{format_union}}
          # TODO: Add read/write mode overrides.
          if format = guess_format?(path)
            format.as?({{format_union}}) || raise ArgumentError.new("#{format} does not support #{type}")
          else
            raise ArgumentError.new("File format not found for #{path}")
          end
        end

        # Returns the format compatible with `{{tres}}` based on *path* or `nil` if the format does not support *type* or cannot be determined.
        #
        # This method effectively narrows down the union of available formats to those compatible with *type*.
        # See `.guess_format?(path)` for more details.
        def Chem.guess_format?(path : Path | String, type : {{tres}}.class) : {{format_union}} | Nil
          guess_format?(path).as?({{format_union}})
        end
      {% end %}
    {% end %}
  {% end %}

  {% supported_types = format_table.keys.sort_by(&.name).join(", ").id %}

  # :nodoc:
  def Chem.guess_format(path : Path | String, type : T.class) : NoReturn forall T
    \{% raise "No format registered for #{T}. Supported types are {{supported_types}}" %}
  end

  # :nodoc:
  def Chem.guess_format?(path : Path | String, type : T.class) : NoReturn forall T
    \{% raise "No format registered for #{T}. Supported types are {{supported_types}}" %}
  end
end
