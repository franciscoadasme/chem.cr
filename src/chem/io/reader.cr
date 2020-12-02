module Chem
  module IO::Reader(T)
    property? sync_close = false
    getter? closed = false

    abstract def read : T

    macro needs(decl)
      {% unless decl.is_a?(TypeDeclaration) %}
        {% raise "'needs' expects a type declaration like 'name : String', " \
                 "got: '#{decl}' in #{@type}" %}
      {% end %}
      {% if decl.var.stringify.ends_with?("?") %}
        {% raise "Don't use '?' with 'needs', got '#{decl}' in #{@type}. " \
                 "A question method is generated if the type is Bool" %}
      {% end %}
      {% if decl.var.stringify.starts_with?("@") %}
        {% raise "Don't use '@' with 'needs', got '#{decl}' in #{@type}" %}
      {% end %}
      {% ASSIGNS << decl %}
      
      def {{decl.var}}{% if decl.type.resolve == Bool %}?{% end %}
        @{{decl.var}}
      end
    end

    macro included
      ASSIGNS = [] of Nil
      
      setup_initializer_hook
    end

    def close
      return if @closed
      @closed = true
      @io.close if @sync_close
    end

    def parse_exception(msg : String)
      raise ParseException.new msg
    end

    private macro generate_initializer
      {% assigns = ASSIGNS.sort_by do |decl|
           has_explicit_value =
             decl.type.is_a?(Metaclass) ||
               decl.type.types.map(&.id).includes?(Nil.id) ||
               decl.value ||
               decl.value == nil ||
               decl.value == false
           has_explicit_value ? 1 : 0
         end %}

      def initialize(
        io : ::IO,
        {% for assign in assigns %}
          @{{assign}},
        {% end %}
        @sync_close : Bool = false,
      )
        @io = IO::TextIO.new io
      end
      
      def self.new(
        path : Path | String,
        {% for decl in assigns %}
          {{decl}},
        {% end %}
      ) : self
        new File.open(path),
          {% for decl in assigns %}
            {{decl.var}},
          {% end %}
          sync_close: true
      end

      def self.open(
        io : ::IO,
        {% for decl in assigns %}
          {{decl}},
        {% end %}
        sync_close : Bool = false,
        &
      )
        reader = new io,
          {% for decl in assigns %}
            {{decl.var}},
          {% end %}
          sync_close: sync_close
        yield reader ensure reader.close
      end

      def self.open(
        path : Path | String,
        {% for decl in assigns %}
          {{decl}},
        {% end %}
        &
      )
        reader = new path{% unless assigns.empty? %},{% end %}
          {% for decl, i in assigns %}
            {{decl.var}}{% if i < assigns.size - 1 %},{% end %}
          {% end %}
        yield reader ensure reader.close
      end
    end

    private macro setup_initializer_hook
      macro finished
        {% unless @type.module? || @type.abstract? %}
          generate_initializer
        {% end %}
      end
  
      macro included
        ASSIGNS = [] of Nil

        setup_initializer_hook
      end
    end

    protected def check_eof(skip_lines : Bool = true)
      if skip_lines
        @io.skip_whitespace
      else
        @io.skip_spaces
      end
      raise ::IO::EOFError.new if @io.eof?
    end

    protected def check_open
      raise ::IO::Error.new "Closed IO" if closed?
    end
  end

  module IO::MultiReader(T)
    abstract def read_next : T?
    abstract def skip : Nil

    def each(& : T ->)
      while ele = read_next
        yield ele
      end
    end

    def each(indexes : Enumerable(Int), & : T ->)
      (indexes.max + 1).times do |i|
        if i.in?(indexes)
          ele = read_next
          raise IndexError.new unless ele
          yield ele
        else
          skip
        end
      end
    end

    def read : T
      read_next || raise ::IO::EOFError.new
    end
  end

  module Spatial::Grid::Reader
    abstract def info : Spatial::Grid::Info
  end

  macro finished
    {% includers = IO::Reader.includers %}
    {% for reader in includers.select(&.annotation(IO::FileType)) %}
      {% type = reader.annotation(IO::FileType)[0].resolve %}
      {% keyword = "class" if type.class? %}
      {% keyword = "struct" if type.struct? %}
      {% format = reader.annotation(IO::FileType)[:format].id.underscore %}

      {{keyword.id}} ::{{type.id}}
        def self.from_{{format.id}}(input : ::IO | Path | String, *args, **options) : self
          {{reader}}.open(input, *args, **options) do |reader|
            reader.read
          end
        end
      end

      {% if reader < IO::MultiReader %}
        class ::Array(T)
          def self.from_{{format.id}}(input : ::IO | Path | String, *args, **options) : self
            {{reader}}.open(input, *args, **options) do |reader|
              ary = [] of T
              reader.each { |ele| ary << ele }
              ary
            end
          end

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
  end
end
