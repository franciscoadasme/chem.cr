# A `Metadata` is a hash-like container that holds metadata about an
# object. It maps a property name (as string) to a primitive value
# (integer, float, string, or bool). Most of the functionality mirrors
# that of a `Hash`, where some specific methods like `Hash#dig` or
# default values are excluded.
#
# Values are stored as `Any` instances, which a thin wrapper for a
# dynamically-typed primitive value and it offers convenient `#as_*`
# cast methods.
#
# ### Examples
#
# ```
# metadata = Chem::Metadata.new
#
# # only four data types are supported
# metadata["str"] = "Foo"
# metadata["int"] = 123
# metadata["float"] = 1.234
# metadata["bool"] = true
# # metadata["x"] = /[a-z]/ # fails to compile
#
# # values are stored as `Any` instances
# metadata["str"]             # => Chem::Metadata::Type("Foo")
# metadata["str"].as_s.upcase # => "FOO"
# metadata["str"].as_i?       # => nil
# metadata["str"].as_i        # raises TypeCastError
# ```
class Chem::Metadata
  # Union of possible metadata value types.
  alias ValueType = Int32 | Float64 | String | Bool

  include Enumerable({String, ValueType})
  include Iterable({String, ValueType})

  # `Any` wraps a value that can be any of the possible metadata
  # types (`ValueType`). It provides convenient `#as_*` cast methods.
  struct Any
    # Returns the enclosed value.
    getter raw : ValueType

    # Creates a new `Any` instance by enclosing the given value.
    def initialize(@raw : ValueType)
    end

    # Returns `true` if the enclosed values are equal, else `false`.
    #
    # ```
    # Chem::Metadata::Any.new("123") == Chem::Metadata::Any.new("123") # => true
    # Chem::Metadata::Any.new("123") == Chem::Metadata::Any.new(123)   # => false
    # ```
    def ==(rhs : self) : Bool
      @raw == rhs.raw
    end

    # Returns `true` if the enclosed value is equal to *rhs*, else `false`.
    #
    # ```
    # Chem::Metadata::Any.new("123") == "123" # => true
    # Chem::Metadata::Any.new("123") == 123   # => false
    # ```
    def ==(rhs) : Bool
      @raw == rhs
    end

    # Returns the enclosed value as a bool. Raises `TypeCastError` if
    # it's not a bool.
    def as_bool : Bool
      @raw.as(Bool)
    end

    # Returns the enclosed value as a bool. Returns `nil` if it's not a
    # bool.
    def as_bool? : Bool?
      @raw.as?(Bool)
    end

    # Returns the enclosed value as a float. Raises `TypeCastError` if
    # it's not a float.
    def as_f : Float64
      case raw = @raw
      when Int
        raw.to_f
      else
        raw.as(Float64)
      end
    end

    # Returns the enclosed value as float. Returns `nil` if it's not a
    # float.
    def as_f? : Float64?
      case raw = @raw
      when Int
        raw.to_f
      else
        raw.as?(Float64)
      end
    end

    # Returns the enclosed value as an integer. Raises `TypeCastError`
    # if it's not an integer.
    def as_i : Int32
      @raw.as(Int).to_i
    end

    # Returns the enclosed value as an integer. Returns `nil` if it's
    # not an integer.
    def as_i? : Int32?
      @raw.as?(Int).try &.to_i
    end

    # Returns the enclosed value as a string. Raises `TypeCastError` if
    # it's not a string.
    def as_s : String
      @raw.as(String)
    end

    # Returns the enclosed value as a string. Returns `nil` if it's not
    # a string.
    def as_s? : String?
      @raw.as?(String)
    end

    def inspect(io : IO) : Nil
      io << self.class.name << '('
      @raw.inspect io
      io << ')'
    end

    def to_s(io : IO) : Nil
      @raw.to_s io
    end
  end

  @data = Hash(String, Any).new

  # Returns the value for the given key. Raises `KeyError` if not
  # found.
  def [](key : String) : Any
    @data[key]
  end

  {% for type in ValueType.union_types %}
    # Sets the value of *key* to the given value.
    def []=(key : String, value : {{type}}) : {{type}}
      @data[key] = Any.new(value)
      value
    end
  {% end %}

  # Returns the value for the given key. Returns `nil` if not found.
  def []?(key : String) : Any?
    @data[key]?
  end

  # Empties the `Metadata` and returns it.
  def clear : self
    @data.clear
    self
  end

  # Deletes the key-value pair and returns the value. Returns `nil` if
  # *key* does not exist.
  def delete(key : String) : Any?
    @data.delete(key)
  end

  # Deletes the key-value pair and returns the value. Yields *key* and
  # returns the value returned by the given block if *key* does not
  # exist.
  def delete(key : String, & : String -> T) : Any | T forall T
    @data.delete(key) { |key| yield key }
  end

  def each(& : {String, Any} ->) : Nil
    @data.each do |keyvalue|
      yield keyvalue
    end
  end

  def each : Iterator({String, Any})
    @data.each
  end

  # Yields each key to the given block.
  #
  # The enumeration follows the order the keys were inserted.
  def each_key(& : String ->) : Nil
    @data.each_key { |key| yield key }
  end

  # Returns an iterator over the keys.
  def each_key : Iterator(String)
    @data.each_key
  end

  # Yields each value to the given block.
  #
  # The enumeration follows the order the keys were inserted.
  def each_value(& : Any ->) : Nil
    @data.each_value { |value| yield value }
  end

  # Returns an iterator over the values.
  def each_value : Iterator(Any)
    @data.each_value
  end

  # Returns `true` when the metadata contains no key-value pairs, else
  # `false`.
  def empty? : Bool
    @data.empty?
  end

  # Returns the value if the given key exists, else *default*.
  def fetch(key : String, default : T) : Any | T forall T
    @data.fetch(key, default)
  end

  # Returns the value if the given key exists, else the value returned
  # by the given block invoked with *key*.
  def fetch(key : String, & : String -> T) : Any | T forall T
    @data.fetch(key) { |key| yield key }
  end

  # Returns `true` if *key* exists, else `false`.
  def has_key?(key : String) : Bool
    @data.has_key?(key)
  end

  # Returns `true` if any key is associated with *value*, else
  # `false`.
  def has_value?(value : ValueType) : Bool
    @data.has_value?(value)
  end

  def inspect(io : IO) : Nil
    io << self.class.name
    to_s io
  end

  # Returns a key with the given value. Raises `KeyError` if no key is
  # associated with *value*.
  def key_for(value : ValueType) : String
    @data.key_for(value)
  end

  {% for type in ValueType.union_types %}
    # Returns a key with the given value. Yields *value* to the given
    # block and returns the returned value if no key is associated with
    # *value*.
    def key_for(value : {{type}}, & : {{type}} -> T) : String | T forall T
      @data.key_for(value) { |value| yield value }
    end
  {% end %}

  # Returns a key with the given value, or `nil` if no key is
  # associated with *value*.
  def key_for?(value : ValueType) : String?
    @data.key_for?(value)
  end

  # Returns a new `Array` with all the keys.
  def keys : Array(String)
    @data.keys
  end

  # Deletes the entries for which the given block is truthy.
  def reject!(& : String, Any ->) : self
    @data.reject! { |key, value| yield key, value }
    self
  end

  # Deletes the entries for the given keys.
  def reject!(keys : Enumerable(String)) : self
    @data.reject!(keys)
    self
  end

  # :ditto:
  def reject!(*keys : String) : self
    @data.reject!(*keys)
    self
  end

  # Deletes every entry except for which the given block is falsey.
  def select!(& : String, Any ->) : self
    @data.select! { |key, value| yield key, value }
    self
  end

  # Deletes every entry except for the given keys.
  def select!(keys : Enumerable(String)) : self
    @data.select!(keys)
    self
  end

  # :ditto:
  def select!(*keys : String) : self
    @data.select!(*keys)
    self
  end

  # Returns the number of key-value pairs.
  def size : Int32
    @data.size
  end

  # Returns an array containing key-value pairs as tuples.
  def to_a : Array({String, Any})
    @data.to_a
  end

  def to_s(io : IO) : Nil
    io << '{'
    each_with_index do |(key, value), i|
      key.inspect io
      io << " => "
      value.raw.inspect io
      io << ", " if i < size - 1
    end
    io << '}'
  end

  # Yields the value for the given key and updates it with the value
  # returned by the given block. Raises `KeyError` if *key* does not
  # exist.
  #
  # It returns the value used as input for the given block (i.e., the
  # old value).
  def update(key : String, & : Any -> ValueType) : Any
    @data.update(key) { |value| Any.new(yield value) }
  end

  # Returns an array containing the values.
  def values : Array(Any)
    @data.values
  end

  # Returns the values for the given keys. Raises `KeyError` if a key
  # does not exist.
  #
  # Values are returned in the same order of the keys.
  def values_at(keys : Enumerable(String)) : Array(Any)
    keys.map { |key| @data[key] }
  end

  # :ditto:
  def values_at(*keys : String)
    @data.values_at(*keys)
  end
end
