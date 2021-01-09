# Defines a common interface for types enclosing an `IO`.
#
# Including types must define the `@io` instance variable to store the
# underlying IO upon initialization.
#
# Use the `Assignable.needs` macro to declare initialization options,
# which will be included as arguments in the `initialize` and `open`
# methods that is generated on compilation time in the concrete class
# via the `generate_initializer` hook. The generated methods are the
# following:
#
# * `initialize(io : IO, ..., sync_close : Bool = false)`
# * `self.new(path : String | Path, ...)`
# * `self.open(io : IO, ..., sync_close : Bool = false)`
# * `self.open(path : String | Path, ...)`
#
# Ellipsis stand for specified arguments via the `Assignable.needs`
# macro. Using a filepath for instantiation will create an underlying
# `IO` object that will be closed when the wrapper object is also
# closed.
#
# ```
# class KeyValueBuilder
#   include IOWrapper
#
#   needs int_format : String
#   needs float_format : String
#
#   @io : IO
#
#   def write(key : String, value)
#     check_open
#     @io << key << " = "
#     case value
#     when Int   then @io.printf @int_format, value
#     when Float then @io.printf @float_format, value
#     else            @io << value
#     end
#     @io << '\n'
#   end
# end
#
# io = IO::Memory.new
# builder = KeyValueBuilder.new io, int_format: "%8d", float_format: "%8.3f"
# builder.closed?    # => false
# builder.sync_close # => false
#
# builder.write "foo", 123
# builder.write "bar", 341.12
# builder.write "baz", "FooBarBaz"
#
# builder.sync_close = true
# builder.close
# builder.closed? # => true
# io.closed?      # => true
#
# puts io.to_s
# ```
#
# Prints:
#
# ```text
# foo =      123
# bar =  341.120
# baz = FooBarBaz
# ```
#
# Alternatively, the above could be written as:
#
# ```crystal
# KeyValueBuilder.open(io, int_format: "%8d", float_format: "%8.3f") do |builder|
#   builder.write "foo", 123
#   builder.write "bar", 341.12
#   builder.write "baz", "FooBarBaz"
# end
# ```
module IOWrapper
  include Assignable

  # File open mode. May be overriden by including types.
  FILE_MODE = "r"

  # Whether to close the enclosed `IO` when closing this object.
  property? sync_close = false

  # Returns `true` if this object is closed.
  getter? closed = false

  # Closes this object. If *sync_close* is true, it will also close the
  # enclosed `IO`.
  def close
    return if @closed
    @closed = true
    @io.close if @sync_close
  end

  # Raises an `IO::Error` if the underlying IO is closed.
  protected def check_open
    raise ::IO::Error.new "Closed IO" if closed?
  end

  # Defines `initialize` and `open` methods based on the declared
  # instantiation arguments. The latter are marked via the
  # `Assignable.needs` macro. The first parameter of the generated
  # methods is either an `IO` object or a file path, followed by the
  # declared arguments.
  #
  # NOTE: Do not call this method directly.
  macro generate_initializer
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
    #
    # An `IO` object will be created and open for the given *path*,
    # which will be closed when closing this object (equivalent to set
    # `sync_close` to `true`).
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
