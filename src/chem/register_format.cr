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

  FORMAT_TYPES = [] of Nil
end

# Gather, check and annotate types registering a format
macro finished
  # gather annotated types under the Chem module
  {% nodes = [Chem] %}
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

    {% read_type = head_type = attached_type = nil %}
    {% if reader = ftype.constant(ann[:reader] || "Reader") %}
      {% read_type = reader.ancestors.select(&.<=(Chem::FormatReader))[-1] %}
      {% reader.raise "#{reader} must include #{Chem::FormatReader}" unless read_type %}

      {% head_type = reader.ancestors.select(&.<=(Chem::FormatReader::Headed))[-1] %}
      {% attached_type = reader.ancestors.select(&.<=(Chem::FormatReader::Attached))[-1] %}
    {% end %}

    {% write_type = nil %}
    {% if writer = ftype.constant(ann[:writer] || "Writer") %}
      {% write_type = writer.ancestors.select(&.<=(Chem::FormatWriter))[-1] %}
      {% writer.raise "#{writer} must include #{Chem::FormatWriter}" unless write_type %}
    {% end %}

    {% keyword = "module" if ftype.module? %}
    {% keyword = "class" if ftype.class? %}
    {% keyword = "struct" if ftype.struct? %}
    {{keyword.id}} {{ftype}}
      FORMAT_NAME = "{{format}}"
      FORMAT_METHOD_NAME = "{{method_name}}"
      {% if reader %}
        READER = {{reader}}
      {% end %}
      {% if read_type %}
        READ_TYPE = {{read_type.type_vars[0]}}
      {% end %}
      {% if head_type %}
        HEAD_TYPE = {{head_type.type_vars[0]}}
      {% end %}
      {% if attached_type %}
        ATTACHED_TYPE = {{attached_type.type_vars[0]}}
      {% end %}
      {% if writer %}
        WRITER = {{writer}}
      {% end %}
      {% if write_type %}
        WRITE_TYPE = {{write_type.type_vars[0]}}
      {% end %}
    end
  {% end %}
end

# Generate methods on encoded types
macro finished
  {% encoded_types = [] of TypeNode %}
  {% for ftype in Chem::FORMAT_TYPES %}
    {% for cname in %w(READ_TYPE HEAD_TYPE ATTACHED_TYPE WRITE_TYPE) %}
      {% if type = ftype.constant(cname) %}
        {% type = type.resolve %}
        {% encoded_types << type unless encoded_types.includes?(type) %}
      {% end %}
    {% end %}
  {% end %}

  {% for etype in encoded_types %}
    {% type_name = etype.name.split("::")[-1].underscore.gsub(/_/, " ") %}
    {% keyword = "module" if etype.module? %}
    {% keyword = "class" if etype.class? %}
    {% keyword = "struct" if etype.struct? %}

    {% rtypes = Chem::FORMAT_TYPES.select &.constant("READ_TYPE").id.==(etype.id) %}
    {% htypes = Chem::FORMAT_TYPES.select &.constant("HEAD_TYPE").id.==(etype.id) %}
    {% atypes = Chem::FORMAT_TYPES.select &.constant("ATTACHED_TYPE").id.==(etype.id) %}
    {% decoding_types = rtypes + htypes + atypes %}
    {% argless_types = [] of TypeNode %}
    {% for ftype in decoding_types %}
      {% reader = ftype.constant("READER").resolve %}
      {% kind = :read if rtypes.includes?(ftype) %}
      {% kind = :head if htypes.includes?(ftype) %}
      {% kind = :attached if atypes.includes?(ftype) %}

      # look for a constructor (including ancestors) & gather required args
      {% constructor = reader.methods.find &.name.==("initialize") %}
      {% for type in reader.ancestors %}
        {% constructor ||= type.methods.find(&.name.==("initialize")) %}
      {% end %}
      {% if constructor %}
        {% args = constructor.args.select do |arg|
             !%w(io sync_close).includes? arg.name.stringify
           end %}
      {% else %}
        {% args = [] of Nil %}
      {% end %}
      {% argless_types << ftype unless args.any? &.default_value.is_a?(Nop) %}

      # auxiliary values for method generation
      {% method_name = ftype.constant("FORMAT_METHOD_NAME").id %}
      {% type_docs, read_suffix = type_name, "entry" if kind == :read %}
      {% type_docs = read_suffix = "header" if kind == :head %}
      {% type_docs, read_suffix = type_name, "attached" if kind == :attached %}

      {{keyword.id}} {{etype}}
        # Returns the {{type_docs.id}} encoded in *input* using the
        # `{{ftype}}` file format. Arguments are forwarded to
        # `{{reader}}#open`.
        def self.from_{{method_name}}(
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
            reader.read_{{read_suffix.id}}
          end
        end
      end

      {% if kind == :read && reader < Chem::FormatReader::MultiEntry %}
        class Array(T)
          # Creates a new array of `{{etype}}` with the entries
          # encoded in *input* using the `{{ftype}}` file format.
          # Arguments are fowarded to `{{reader}}#open`.
          def self.from_{{method_name}}(
            input : IO | Path | String,
            {% for arg in args %}
              {{arg}},
            {% end %}
          ) : self
            \{% unless (type = @type) <= Array({{etype}}) %}
              \{% raise "undefined method '.from_{{method_name}}' for #{type}.class" %}
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

          # Creates a new array of `{{etype}}` with the entries at
          # *indexes* encoded in *input* using the `{{ftype}}` file
          # format. Arguments are fowarded to `{{reader}}#open`.
          def self.from_{{method_name}}(
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
    {% end %}

    {% unless argless_types.empty? %}
      {% type_docs = type_name %}
      {% type_docs = "header" if rtypes.empty? && atypes.empty? %}
      {% format_docs = argless_types.map { |t| "`#{t}`".id }.sort %}

      {{keyword.id}} {{etype}}
        # Returns the {{type_docs.id}} encoded in the specified file.
        # The file format is chosen based on the filename (see
        # `Chem::Format#from_filename`). Raises `ArgumentError` if the
        # file format cannot be determined.
        #
        # The supported file formats are {{format_docs.splat}}. Use the
        # `.from_*` methods to customize how the object is decoded in
        # the corresponding file format if possible.
        def self.read(path : Path | String) : self
          read path, ::Chem::Format.from_filename(path)
        end

        # Returns the {{type_docs.id}} encoded in the specified file
        # using *format*. Raises `ArgumentError` if *format* has
        # required arguments, it is not supported or invalid.
        #
        # The supported file formats are {{format_docs.splat}}. Use the
        # `.from_*` methods to customize how the object is decoded in
        # the corresponding file format if possible.
        def self.read(input : IO | Path | String,
                      format : ::Chem::Format | String) : self
          format = ::Chem::Format.parse format if format.is_a?(String)
          {% begin %}
            case format
            {% for ftype in decoding_types %}
              {% method_name = ftype.constant("FORMAT_METHOD_NAME").id %}
              when .{{method_name}}?
                {% if argless_types.includes?(ftype) %}
                  from_{{method_name}} input
                {% else %}
                  raise ArgumentError.new "#{format} format has required arguments. \
                                           Use `.from_{{method_name}}` instead."
                {% end %}
            {% end %}
            else
              raise ArgumentError.new "#{format} does not encode {{etype}}"
            end
          {% end %}
        end
      end
    {% end %}

    {% encoding_types = Chem::FORMAT_TYPES.select do |t|
         (write_type = t.constant("WRITE_TYPE")) && etype <= write_type.resolve
       end %}
    {% argless_types = [] of TypeNode %}
    {% for ftype in encoding_types %}
      {% writer = ftype.constant("WRITER").resolve %}
      {% method_name = ftype.constant("FORMAT_METHOD_NAME").id %}

      # look for a constructor (including ancestors) & gather required args
      {% constructor = writer.methods.find &.name.==("initialize") %}
      {% for type in writer.ancestors %}
        {% constructor ||= type.methods.find(&.name.==("initialize")) %}
      {% end %}
      {% if constructor %}
        {% known_args = %w(io sync_close) %}
        {% known_args << "total_entries" if writer < Chem::FormatWriter::MultiEntry %}
        {% args = constructor.args.reject { |x| known_args.includes? x.name.stringify } %}
      {% else %}
        {% args = [] of Nil %}
      {% end %}
      {% argless_types << ftype unless args.any? &.default_value.is_a?(Nop) %}

      {{keyword.id}} {{etype}}
        # Returns a string representation of the {{type_name.id}} using
        # the `{{ftype}}` file format. Arguments are fowarded to
        # `{{writer}}#open`.
        def to_{{method_name}}(
          {% for arg in args %}
            {{arg}},
          {% end %}
        ) : String
          String.build do |io|
            to_{{method_name}}(
              io \
              {% for arg in args %} \
                ,{{arg.internal_name}} \
              {% end %}
            )
          end
        end

        # Writes the {{type_name.id}} to *output* using the `{{ftype}}`
        # file format. Arguments are fowarded to `{{writer}}#open`.
        def to_{{method_name}}(
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
            writer << self
          end
        end
      end

      {% if writer < Chem::FormatWriter::MultiEntry %}
        class Array(T)
          # Returns a string representation of the elements encoded in
          # the `{{ftype}}` file format. Arguments are fowarded to
          # `{{writer}}#open`.
          def to_{{method_name}}(
            {% for arg in args %}
              {{arg}},
            {% end %}
          ) : String
            \{% unless (type = @type.type_vars[0]) <= {{etype}} %}
              \{% raise "undefined method 'to_{{method_name}}' for #{@type}.class" %}
            \{% end %}
            String.build do |io|
              to_{{method_name}}(
                io \
                {% for arg in args %} \
                  ,{{arg.internal_name}} \
                {% end %}
              )
            end
          end

          # Writes the elements to *output* using the `{{ftype}}` file
          # format. Arguments are fowarded to `{{writer}}#open`.
          def to_{{method_name}}(
            output : IO | Path | String,
            {% for arg in args %}
              {{arg}},
            {% end %}
          ) : Nil
            \{% unless (type = @type.type_vars[0]) <= {{etype}} %}
              \{% raise "undefined method 'to_{{method_name}}' for #{@type}.class" %}
            \{% end %}
            {{writer}}.open(
              output,
              {% for arg in args %}
                {{arg.internal_name}},
              {% end %}
              total_entries: size
            ) do |writer|
              each do |obj|
                writer << obj
              end
            end
          end
        end
      {% end %}
    {% end %}

    {% unless argless_types.empty? %}
      {% format_docs = argless_types.map { |t| "`#{t}`".id }.sort %}

      {{keyword.id}} {{etype}}
        # Writes the {{type_name.id}} to the specified file. The file
        # format is chosen based on the filename (see
        # `Chem::Format#from_filename`). Raises `ArgumentError` if the
        # file format cannot be determined.
        #
        # The supported file formats are {{format_docs.splat}}. Use the
        # `#to_*` methods to customize how the object is written in the
        # corresponding file format if possible.
        def write(path : Path | String) : Nil
          write path, ::Chem::Format.from_filename(path)
        end

        # Writes the {{type_name.id}} to *output* using *format*. Raises
        # `ArgumentError` if *format* has required arguments, it is not
        # supported or invalid.
        #
        # The supported file formats are {{format_docs.splat}}. Use the
        # `#to_*` methods to customize how the object is written in the
        # corresponding file format if possible.
        def write(output : IO | Path | String, format : ::Chem::Format | String) : Nil
          format = ::Chem::Format.parse format if format.is_a?(String)
          {% begin %}
            case format
            {% for ftype in encoding_types %}
              {% method_name = ftype.constant("FORMAT_METHOD_NAME").id %}
              when .{{method_name}}?
                {% if argless_types.includes?(ftype) %}
                  to_{{method_name}} output
                {% else %}
                  raise ArgumentError.new "#{format} format has required arguments. \
                                           Use `#to_{{method_name}}` instead."
                {% end %}
            {% end %}
            else
              raise ArgumentError.new "#{format} does not encode {{etype}}"
            end
          {% end %}
        end
      end
    {% end %}
  {% end %}
end
