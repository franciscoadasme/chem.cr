module IOWrapper
  include Assignable

  FILE_MODE = "r"

  # Whether to close the enclosed `IO` when closing this reader.
  property? sync_close = false

  # Returns `true` if this reader is closed.
  getter? closed = false

  # Closes this reader. If *sync_close* is true, it will also close the
  # enclosed `IO`.
  def close
    return if @closed
    @closed = true
    @io.close if @sync_close
  end

  protected def check_open
    raise ::IO::Error.new "Closed IO" if closed?
  end

  private macro generate_initializer
    {% args = (ASSIGNABLES[@type] || [] of TypeDeclaration).sort_by do |decl|
         has_explicit_value =
           decl.type.is_a?(Metaclass) ||
             decl.type.types.map(&.id).includes?(Nil.id) ||
             decl.value ||
             decl.value == nil ||
             decl.value == false
         has_explicit_value ? 1 : 0
       end %}

    # Creates a new reader from the given *io*. The arguments are those
    # marked as needed for instantiation.
    def initialize(
      @io : ::IO,
      {% for decl in args %}
        {% nilable = decl.value.is_a?(Nop) && decl.type.resolve.nilable? %}
        @{{decl}}{% if nilable %} = nil{% end %},
      {% end %}
      @sync_close : Bool = false,
    )
    end

    # Creates a new reader from the given *path*. The arguments are
    # those marked as needed for instantiation.
    def self.new(
      path : Path | String,
      {% for decl in args %}
        {% nilable = decl.value.is_a?(Nop) && decl.type.resolve.nilable? %}
        {{decl}}{% if nilable %} = nil{% end %},
      {% end %}
    ) : self
      new File.new(path, FILE_MODE),
        {% for decl in args %}
          {{decl.var}},
        {% end %}
        sync_close: true
    end

    # Creates a new reader from the given *io*, yields it to the given
    # block, and closes it at the end. The arguments are those marked as
    # needed for instantiation.
    def self.open(
      io : ::IO,
      {% for decl in args %}
        {% nilable = decl.value.is_a?(Nop) && decl.type.resolve.nilable? %}
        {{decl}}{% if nilable %} = nil{% end %},
      {% end %}
      sync_close : Bool = false,
      & : self ->
    )
      reader = new io,
        {% for decl in args %}
          {{decl.var}},
        {% end %}
        sync_close: sync_close
      yield reader ensure reader.close
    end

    # Creates a new reader from the given *path*, yields it to the given
    # block, and closes it at the end. The arguments are those marked as
    # needed for instantiation.
    def self.open(
      path : Path | String,
      {% for decl in args %}
        {% nilable = decl.value.is_a?(Nop) && decl.type.resolve.nilable? %}
        {{decl}}{% if nilable %} = nil{% end %},
      {% end %}
      & : self ->
    )
      reader = new path{% unless args.empty? %},{% end %}
        {% for decl, i in args %}
          {{decl.var}}{% if i < args.size - 1 %},{% end %}
        {% end %}
      yield reader ensure reader.close
    end
  end
end
