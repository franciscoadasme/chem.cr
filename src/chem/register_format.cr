module Chem
  # Registers a file format.
  #
  # A file type associates extensions and/or file names with a file format, and links
  # the latter to the annotated classes. If the file format does not exist, it is
  # registered.
  #
  # This annotation accepts the file format (required), and either an array of
  # extensions (without leading dot) or an array of file names, or both. File names can
  # include wildcards (*) to denote either prefix (e.g., "Foo*"), suffix (e.g., "*Bar"),
  # or both (e.g., "*Baz*").
  #
  # ```
  # @[RegisterFormat(format: Log, ext: %w(txt log out), names: %w(LOG *OUT))]
  # class LogParser
  # end
  # ```
  annotation RegisterFormat; end
end

macro finished
  # List of annotated types
  {% annotated_types = [] of TypeNode %}
  # Maps format name to annotated type
  {% format_map = {} of String => TypeNode %}
  # Maps annotated type to method format name
  {% method_format_map = {} of TypeNode => MacroId %}
  # Maps extension to annotated type
  {% ext_map = {} of String => TypeNode %}
  # Maps file pattern (without *) to annotated type
  {% name_map = {} of String => TypeNode %}
  # Maps encoded type to a list of read types
  {% read_map = {} of TypeNode => Array(TypeNode) %}
  # Maps encoded type to a list of write types
  {% write_map = {} of TypeNode => Array(TypeNode) %}
  # Maps encoded type to a list of header types
  {% head_map = {} of TypeNode => Array(TypeNode) %}
  # Maps encoded type to a list of header types
  {% attach_map = {} of TypeNode => Array(TypeNode) %}
  # List of argless reader/writers (no required args in the constructor)
  {% argless_types = [] of TypeNode %}

  # gather annotated types under the Chem module
  {% nodes = [Chem] %}
  {% for node in nodes %}
    {% annotated_types << node if node.annotation(Chem::RegisterFormat) %}
    {% for c in node.constants.map { |c| node.constant(c) } %}
      {% nodes << c if c.is_a?(TypeNode) && (c.class? || c.struct? || c.module?) %}
    {% end %}
  {% end %}

  {% for ann_type in annotated_types %}
    {% ann = ann_type.annotation(Chem::RegisterFormat) %}

    # Checks for format name collisions
    {% format = ann_type.name.split("::")[-1].id %}
    {% method_format = format.downcase %}
    {% method_format_map[ann_type] = method_format %}
    {% if type = format_map[format] %}
      {% ann.raise "Format #{format} in #{ann_type} is registered to #{type}" %}
    {% end %}
    {% format_map[format] = ann_type %}

    # Checks for extension collisions
    {% for ext in (ann[:ext] || [] of Nil) %}
      {% if type = ext_map[ext] %}
        {% ann.raise "Extension #{ext.id} in #{ann_type} is registered to #{type}" %}
      {% end %}
      {% ext_map[ext] = ann_type %}
    {% end %}

    # Checks for file pattern collisions
    {% for name_spec in (ann[:names] || [] of Nil) %}
      {% key = name_spec.tr("*", "").camelcase.underscore %}
      {% if type = name_map[key] %}
        {% ann.raise "File pattern #{name_spec.id} in #{ann_type} is \
                      registered to #{type}" %}
      {% end %}
      {% name_map[key] = ann_type %}
    {% end %}

    {% if reader = ann_type.constant(ann[:reader] || "Reader") %}
      {% encoded_type = reader.ancestors.select(&.<=(Chem::FormatReader))[-1] %}
      {% if encoded_type %}
        {% encoded_type = encoded_type.type_vars[0] %}
      {% else %}
        {% reader.raise "#{reader} must include #{Chem::FormatReader}" %}
      {% end %}
      {% type_desc = encoded_type.name.split("::")[-1].underscore.gsub(/_/, " ").id %}

      # register read for encoded type
      {% if read_map[encoded_type] %}
        {% read_map[encoded_type] << ann_type %}
      {% else %}
        {% read_map[encoded_type] = [ann_type] %}
      {% end %}

      {% keyword = "module" if encoded_type.module? %}
      {% keyword = "class" if encoded_type.class? %}
      {% keyword = "struct" if encoded_type.struct? %}

      # look for constructor (including ancestors)
      {% constructor = reader.methods.find &.name.==("initialize") %}
      {% for type in reader.ancestors %}
        {% constructor ||= type.methods.find(&.name.==("initialize")) %}
      {% end %}

      # gather constructor args
      {% if constructor %}
        {% args = constructor.args.select do |arg|
             !%w(io sync_close).includes? arg.name.stringify
           end %}
      {% else %}
        {% args = [] of Nil %}
      {% end %}
      {% argless_types << reader unless args.any? &.default_value.is_a?(Nop) %}

      {{keyword.id}} {{encoded_type}}
        # Returns the {{type_desc}} encoded in *input* using the
        # `{{ann_type}}` file format. Arguments are forwarded to
        # `{{reader}}#open`.
        def self.from_{{method_format}}(
          input : IO | Path | String,
          {% for arg in args %}
            {{arg}},
          {% end %}
        ) : self
          {{reader}}.open(
            input \
            {% for arg in args %} \
              ,{{arg.internal_name}} \
            {% end %}
          ) do |reader|
            reader.read_entry
          end
        end
      end

      {% if reader < Chem::FormatReader::MultiEntry %}
        class Array(T)
          # Creates a new array of `{{encoded_type}}` with the entries
          # encoded in *input* using the `{{ann_type}}` file format.
          # Arguments are fowarded to `{{reader}}#open`.
          def self.from_{{method_format}}(
            input : IO | Path | String,
            {% for arg in args %}
              {{arg}},
            {% end %}
          ) : self
            \{% unless (type = @type) <= Array({{encoded_type}}) %}
              \{% raise "undefined method '.from_{{method_format}}' for #{type}.class" %}
            \{% end %}
            {{reader}}.open(
              input \
              {% for arg in args %} \
                ,{{arg.internal_name}} \
              {% end %}
            ) do |reader|
              Array(T).new.tap do |ary|
                reader.each { |obj| ary << obj }
              end
            end
          end

          # Creates a new array of `{{encoded_type}}` with the entries
          # at *indexes* encoded in *input* using the `{{ann_type}}`
          # file format. Arguments are fowarded to `{{reader}}#open`.
          def self.from_{{method_format}}(
            input : IO | Path | String,
            indexes : Array(Int),
            {% for arg in args %}
              {{arg}},
            {% end %}
          ) : self
            {{reader}}.open(
              input \
              {% for arg in args %} \
              ,{{arg.internal_name}} \
              {% end %}
            ) do |reader|
              Array(T).new(indexes.size).tap do |ary|
                reader.each(indexes) { |obj| ary << obj }
              end
            end
          end
        end
      {% end %}

      {% for mixin in [Chem::FormatReader::Headed, Chem::FormatReader::Attached] %}
        {% if type = reader.ancestors.select(&.<=(mixin)).map(&.type_vars[0]).first %}
          {% if mixin <= Chem::FormatReader::Headed
               method_name = "header"
               map = head_map
               type_desc = "header".id
             end %}
          {% if mixin <= Chem::FormatReader::Attached
               method_name = "attached"
               map = attach_map
               type_desc = type.name.split("::")[-1].underscore.gsub(/_/, " ").id
             end %}
          {% map[type] ? map[type] << ann_type : (map[type] = [ann_type]) %}

          {% keyword = "module" if type.module? %}
          {% keyword = "class" if type.class? %}
          {% keyword = "struct" if type.struct? %}

          {{keyword.id}} {{type}}
            # Returns the {{type_desc}} encoded in *input* using the
            # `{{ann_type}}` file format. Arguments are forwarded to
            # `{{reader}}#open`.
            def self.from_{{method_format}}(
              input : IO | Path | String,
              {% for arg in args %}
                {{arg}},
              {% end %}
            ) : self
              {{reader}}.open(
                input \
                {% for arg in args %} \
                  ,{{arg.internal_name}} \
                {% end %}
              ) do |reader|
                reader.read_{{method_name.id}}
              end
            end
          end
        {% end %}
      {% end %}
    {% end %}

    {% if writer = ann_type.constant(ann[:writer] || "Writer") %}
      {% encoded_type = writer.ancestors.select(&.<=(Chem::FormatWriter))[-1] %}
      {% if encoded_type %}
        {% encoded_type = encoded_type.type_vars[0] %}
      {% else %}
        {% writer.raise "#{writer} must include #{Chem::FormatWriter}" %}
      {% end %}

      # register write for encoded type
      {% if write_map[encoded_type] %}
        {% write_map[encoded_type] << ann_type %}
      {% else %}
        {% write_map[encoded_type] = [ann_type] %}
      {% end %}

      {% keyword = "module" if encoded_type.module? %}
      {% keyword = "class" if encoded_type.class? %}
      {% keyword = "struct" if encoded_type.struct? %}

      # look for constructor (including ancestors)
      {% constructor = writer.methods.find &.name.==("initialize") %}
      {% for type in writer.ancestors %}
        {% constructor ||= type.methods.find(&.name.==("initialize")) %}
      {% end %}

      # gather constructor args
      {% if constructor %}
        {% args = constructor.args.select do |arg|
             !%w(io sync_close).includes? arg.name.stringify
           end %}
      {% else %}
        {% args = [] of Nil %}
      {% end %}
      {% argless_types << writer unless args.any? &.default_value.is_a?(Nop) %}

      {{keyword.id}} {{encoded_type}}
        # Returns a string representation of this object encoded using
        # the `{{ann_type}}` file format. Arguments are fowarded to
        # `{{writer}}#open`.
        def to_{{method_format}}(
          {% for arg in args %}
            {{arg}},
          {% end %}
        ) : String
          String.build do |io|
            to_{{method_format}}(
              io \
              {% for arg in args %} \
                ,{{arg.internal_name}} \
              {% end %}
            )
          end
        end

        # Writes this object to *output* using the `{{ann_type}}` file
        # format. Arguments are fowarded to `{{writer}}#open`.
        def to_{{method_format}}(
          output : IO | Path | String,
          {% for arg in args %}
            {{arg}},
          {% end %}
        ) : Nil
          {{writer}}.open(
            output \
            {% for arg in args %} \
              ,{{arg.internal_name}} \
            {% end %}
          ) do |writer|
            writer.write self
          end
        end
      end
    {% end %}
  {% end %}

  {% encoded_types = (read_map.keys + head_map.keys + attach_map.keys + write_map.keys).uniq %}
  {% for encoded_type in encoded_types %}
    {% keyword = "module" if encoded_type.module? %}
    {% keyword = "class" if encoded_type.class? %}
    {% keyword = "struct" if encoded_type.struct? %}

    {{keyword.id}} {{encoded_type}}
      {% read_types = [] of TypeNode %}
      {% for map in [read_map, head_map, attach_map] %}
        {% if types = map[encoded_type] %}
          {% read_types += types %}
        {% end %}
      {% end %}
      {% unless read_types.empty? %}
        {% argless_read_types = read_types.select do |t|
             reader = t.constant(ann[:reader] || "Reader")
             argless_types.includes? reader
           end %}
        {% printable_formats = read_types.map { |t| "`#{t}`".id }.sort %}

        {% if read_map[encoded_type] || attach_map[encoded_type] %}
          {% type_desc = encoded_type.name.split("::")[-1].underscore.gsub(/_/, " ").id %}
        {% elsif head_map[encoded_type] %}
          {% type_desc = "header".id %}
        {% end %}

        # Returns the {{type_desc}} encoded in the specified file. The
        # file format is chosen based on the filename (see
        # `Chem::Format#from_filename`). Raises `ArgumentError` if the
        # file format cannot be determined.
        #
        # The supported file formats are {{printable_formats.splat}}.
        # Use the `.from_*` methods to customize how the object is
        # decoded in the corresponding file format.
        def self.read(path : Path | String) : self
          read path, ::Chem::Format.from_filename(path)
        end

        # Returns the {{type_desc}} encoded in the specified file using
        # the given file format. Raises `ArgumentError` if *format* has
        # required arguments, it is not supported or invalid.
        #
        # The supported file formats are {{printable_formats.splat}}.
        # Use the `.from_*` methods to customize how the object is
        # decoded in the corresponding file format.
        def self.read(input : IO | Path | String,
                      format : ::Chem::Format | String) : self
          format = ::Chem::Format.parse format if format.is_a?(String)
          {% begin %}
            case format
            {% for read_type in read_types %}
              {% method_format = method_format_map[read_type] %}
              when .{{method_format}}?
                {% if argless_read_types.includes?(read_type) %}
                  from_{{method_format}} input
                {% else %}
                  raise ArgumentError.new "#{format} has required arguments. \
                                           Use `.from_{{method_format}}` instead."
                {% end %}
            {% end %}
            else
              raise ArgumentError.new "#{format} does not encode {{encoded_type}}"
            end
          {% end %}
        end
      {% end %}

      # gather write types including those of superclasses
      {% write_types = write_map[encoded_type] || [] of TypeNode %}
      {% for type in write_map.keys.select { |t| encoded_type < t } %}
        {% write_types += write_map[type] %}
      {% end %}
      {% unless write_types.empty? %}
        {% argless_write_types = write_types.select do |t|
             writer = t.constant(ann[:writer] || "Writer")
             argless_types.includes? writer
           end %}
        {% printable_formats = write_types.map { |t| "`#{t}`".id }.sort %}

        # Writes this object to the specified file. The file format is
        # chosen based on the filename (see
        # `Chem::Format#from_filename`). Raises `ArgumentError` if the
        # file format cannot be determined.
        #
        # The supported file formats are {{printable_formats.splat}}.
        # Use the `#to_*` methods to customize how the object is written
        # in the corresponding file format.
        def write(path : Path | String) : Nil
          write path, ::Chem::Format.from_filename(path)
        end

        # Writes this object to *output* using the given file format.
        # Raises `ArgumentError` if *format* has required arguments, it
        # is not supported or invalid.
        #
        # The supported file formats are {{printable_formats.splat}}.
        # Use the `#to_*` methods to customize how the object is written
        # in the corresponding file format.
        def write(output : IO | Path | String, format : ::Chem::Format | String) : Nil
          format = ::Chem::Format.parse format if format.is_a?(String)
          {% begin %}
            case format
            {% for write_type in write_types %}
              {% method_format = method_format_map[write_type] %}
              when .{{method_format}}?
                {% if argless_write_types.includes?(write_type) %}
                  to_{{method_format}} output
                {% else %}
                  raise ArgumentError.new "#{format} has required arguments. \
                                           Use `#to_{{method_format}}` instead."
                {% end %}
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
