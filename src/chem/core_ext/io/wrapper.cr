# Defines a common interface for types enclosing an `IO`.
#
# A default constructor is defined by this module, which may be
# overridden by the including type. The latter must initialize the `@io`
# (stores the enclosed IO) and `@sync_close` instance variables.
#
# Additionally, the following convenience methods are the generated on
# compile time:
#
# * `self.new(path : String | Path, ...)`
# * `self.open(io : IO, ..., sync_close : Bool = false, & : self ->)`
# * `self.open(path : String | Path, ..., & : self ->)`
#
# Ellipsis stand for the positional and named arguments declared in the
# custom constructor, if any. Note that these methods are generated for
# non-abstract classes and structs, only.
#
# ```
# class LineIO
#   include IO::Wrapper
#
#   getter? chomp : Bool
#
#   def initialize(@io : IO, @chomp = false, @sync_close : Bool = false)
#   end
#
#   def consume_line : String?
#     check_open
#     @io.gets chomp: chomp?
#   end
# end
#
# io = IO::Memory.new "abc\ndef\n"
# line_io = LineIO.new io, chomp: true, sync_close: false
# line_io.closed?    # => false
# line_io.sync_close # => false
#
# line_io.consume_line # => "abc"
# line_io.consume_line # => "def"
# line_io.consume_line # => nil
#
# line_io.sync_close = true
# line_io.close
# line_io.closed? # => true
# io.closed?      # => true
# ```
#
# Alternatively, the above could be written as:
#
# ```
# line = LineIO.open(io, chomp: true) do |line_io|
#   line_io.consume_line
#   line_io.consume_line
# end
# line # => "def"
# ```
module ::IO::Wrapper
  # File open mode. May be overridden by including types.
  FILE_MODE = "r"

  # Returns `true` if this object is closed.
  getter? closed : Bool = false

  # Whether to close the enclosed `IO` when closing this object.
  property sync_close : Bool = false

  # Closes this object. If *sync_close* is true, it will also close the
  # enclosed `IO`.
  def close
    return if @closed
    @closed = true
    @io.close if @sync_close
  end

  # Raises an `IO::Error` if the enclosed `IO` is closed.
  protected def check_open : Nil
    raise IO::Error.new "Closed IO" if closed?
  end

  macro included
    generator_hook
  end

  # Defines convenience `initialize` and `open` methods mirroring the
  # designated constructor. Positional and named arguments are copied
  # from it except for `io` and `sync_close`.
  private macro generate_convenience_constructors
    {% method = @type.methods.find &.name.==("initialize") %}
    # look for #initialize in ancestors
    {% for type in @type.ancestors %}
      {% method ||= type.methods.find(&.name.==("initialize")) %}
    {% end %}

    {% if method %}
      {% if method.args[0].id != "io : IO" %}
        {% method.raise "First argument of `#{@type}#initialize` must be \
                         `io : IO`, not `#{method.args[0]}`" %}
      {% end %}

      {% if arg = method.args.find(&.name.==("sync_close")) %}
        {% if arg.id != "sync_close : Bool = false" %}
          {% method.raise "Argument `sync_close` of `#{@type}#initialize` \
                           must be `sync_close : Bool = false`, not `#{arg}`" %}
        {% end %}
      {% else %}
        {% method.raise "Missing argument `sync_close : Bool = false` in \
                         `#{@type}#initialize`" %}
      {% end %}

      {% args = method.args.select do |arg|
           !%w(io sync_close).includes? arg.name.stringify
         end %}
    {% else %}
      {% args = [] of Nil %}

      # Creates a new object from the given *io*.
      def initialize(@io : IO, @sync_close : Bool = false); end
    {% end %}

    # Creates a new object from the given *path*. Positional and named
    # arguments are forwarded to the designated constructor.
    #
    # An `IO` object will be created and open from the given *path*,
    # which will be closed when closing this object (`sync_close =
    # true`). The file open mode is specified by the `FILE_MODE`
    # constant.
    def self.new(
      path : Path | String,
      {% for arg in args %}
        {{arg}},
      {% end %}
    ) : self
      new File.new(path, FILE_MODE),
        {% for arg in args %}
          {{arg.is_a?(TypeDeclaration) ? arg.var : arg.internal_name}},
        {% end %}
        sync_close: true
    end

    # Creates a new object from the given *io*, yields it to the given
    # block, and closes it at the end. Positional and named arguments
    # are forwarded to the constructor.
    def self.open(
      io : IO,
      {% for arg in args %}
        {{arg}},
      {% end %}
      sync_close : Bool = false,
      & : self ->
    )
      io = new io,
        {% for arg in args %}
          {{arg.is_a?(TypeDeclaration) ? arg.var : arg.internal_name}},
        {% end %}
        sync_close: sync_close
      yield io ensure io.close
    end

    # Creates a new object from the given *path* yields it to the
    # given block, and closes it at the end. Positional and named
    # arguments are forwarded to the constructor.
    #
    # An `IO` object will be created and open from the given *path*,
    # which will be closed when closing this object (`sync_close =
    # true`). The file open mode is specified by the `FILE_MODE`
    # constant.
    def self.open(
      path : Path | String,
      {% for arg in args %}
        {{arg}},
      {% end %}
      & : self ->
    )
      io = new path{{",".id unless args.empty?}}
        {% for arg, i in args %}
          {{arg.is_a?(TypeDeclaration) ? arg.var : arg.internal_name}} \
          {{",".id if i < args.size - 1}}
        {% end %}
      yield io ensure io.close
    end
  end

  # Hook for generating convenience methods.
  #
  # It ensures `generate_convenience_constructors` is called on concrete
  # classes and structs, otherwise registers itself for abstract classes
  # and modules via the `inherited` and `included` hooks, respectively.
  # The latter is needed to account for inheritance/inclusion chains.
  private macro generator_hook
    {% if @type.class? || @type.struct? %}
      {% if @type.abstract? %}
        macro inherited
          generator_hook
        end
      {% else %}
        macro finished
          generate_convenience_constructors
        end
      {% end %}
    {% elsif @type.module? %}
      macro included
        generator_hook
      end
    {% end %}
  end
end
