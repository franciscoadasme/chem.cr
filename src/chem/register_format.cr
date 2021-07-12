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
  # Maps extension to annotated type
  {% ext_map = {} of String => TypeNode %}
  # Maps file name pattern (without *) to annotated type
  {% name_map = {} of String => TypeNode %}

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

    # Checks for file name pattern collisions
    {% for name_spec in (ann[:names] || [] of Nil) %}
      {% key = name_spec.tr("*", "").camelcase.underscore %}
      {% if type = name_map[key] %}
        {% ann.raise "File name pattern #{name_spec.id} in #{ann_type} is \
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

      {{keyword.id}} {{encoded_type}}
        # Returns the object encoded in *input* using the `{{ann_type}}`
        # file format. Arguments are forwarded to `{{reader}}#open`.
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

      class Array(T)
        # Creates a new array with the entries encoded in *input* using
        # the `{{ann_type}}` file format. Arguments are fowarded to
        # `{{reader}}#open`.
        #
        # NOTE: Only works for `{{encoded_type}}`.
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
            reader.to_a
          end
        end

        # Creates a new array with the entries encoded in *input* using
        # the `{{ann_type}}` file format. Entries listed in *indexes*
        # are read only. Arguments are fowarded to `{{reader}}#open`.
        #
        # NOTE: Only works for `{{encoded_type}}`.
        def self.from_{{method_format}}(
          input : IO | Path | String,
          indexes : Array(Int),
          {% for arg in args %}
            {{arg}},
          {% end %}
        ) : self
          ary = Array(Chem::Structure).new indexes.size
          {{reader}}.open(
            input \
            {% for arg in args %} \
              ,{{arg.internal_name}} \
            {% end %}
          ) do |reader|
            reader.each(indexes) { |st| ary << st }
          end
          ary
        end
      end
    {% end %}

    {% if writer = ann_type.constant(ann[:writer] || "Writer") %}
      {% encoded_type = writer.ancestors.select(&.<=(Chem::FormatWriter))[-1] %}
      {% if encoded_type %}
        {% encoded_type = encoded_type.type_vars[0] %}
      {% else %}
        {% writer.raise "#{writer} must include #{Chem::FormatWriter}" %}
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
end
