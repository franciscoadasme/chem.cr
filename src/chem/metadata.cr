# A `Metadata` is a hash-like container that holds metadata about an
# object. It maps a property name (as string) to a primitive value
# (integer, float, string, or bool) or an array of them. Most of the
# functionality mirrors that of a `Hash`, where some specific methods
# like `Hash#dig` or default values are excluded.
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
# # four data types are supported
# metadata["str"] = "Foo"
# metadata["int"] = 123
# metadata["float"] = 1.234
# metadata["bool"] = true
# # metadata["x"] = /[a-z]/ # fails to compile
#
# # (base type) arrays are also supported
# metadata["array_of_int"] = [1, 2, 3]
# metadata["array_of_string"] = %w(1 2 3)
# metadata["nested_array"] = [[1, 2], [3]]
# # metadata["mixed_array"] = [1, "2", true] # does not compile
# ```
#
# Values are stored as `Any` instances. Use `#as_*` cast methods get the
#  actual value.
#
# ```
# metadata["str"]             # => Chem::Metadata::Any("Foo")
# metadata["str"].as_s.upcase # => "FOO"
# metadata["str"].as_i?       # => nil
# metadata["str"].as_i        # raises TypeCastError
# metadata["str"].as_a        # raises TypeCastError
# ```
#
# Arrays are returned as `Array(Any)`. Use `Array#map(&.as_*)` or
# `#as_a(type)` to get a typed array.
#
# ```
# metadata["array_of_int"].as_a             # => [Chem::Metadata::Any(1), ...]
# metadata["array_of_int"].as_a.map(&.as_i) # => [1, 2, 3]
# metadata["array_of_int"].as_a(Int32)      # => [1, 2, 3]
# metadata["nested_array"].as_2a(Int32)     # => [[1, 2], [3]]
# ```
class Chem::Metadata
  # Union of possible metadata value types.
  alias ValueType = Bool | Int32 | Float64 | String

  include Enumerable({String, ValueType})
  include Iterable({String, ValueType})

  # `Any` wraps a value that can be any of the possible metadata
  # types (`ValueType`). It provides convenient `#as_*` cast methods.
  struct Any
    # Returns the enclosed value.
    getter raw : ValueType | Array(ValueType) | Array(Array(ValueType))

    # Creates a new `Any` instance by enclosing the given value.
    def initialize(@raw : ValueType)
    end

    # :ditto:
    def initialize(arr : Array(Array))
      @raw = arr.map do |ele|
        ele.as(Array).map &.as(Int32 | Float64 | Bool | String)
      end
    end

    # :ditto:
    def initialize(arr : Array)
      @raw = arr.map &.as(Int32 | Float64 | Bool | String)
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

    # Returns the enclosed value as an array of `Any`. Raises
    # `TypeCastError` if it's not an array.
    def as_a : Array(Any)
      @raw.as(Array).map { |ele| Any.new(ele) }
    end

    # Returns the enclosed value as an array of `Any`, or `nil` if it's
    # not an array.
    def as_a? : Array(Any)?
      @raw.as?(Array).try &.map { |ele| Any.new(ele) }
    end

    {% for type in [Int32, Float64, String, Bool] %}
      # Returns the enclosed value as a nested array of {{type}}. Raises
      # `TypeCastError` if it's not a nested array of {{type}}.
      def as_2a(type : {{type}}.class) : Array(Array({{type}}))
        @raw.as(Array).map { |ele| ele.as(Array).map &.as({{type}}) }
      end

      # Returns the enclosed value as an nested array of {{type}}, or
      # `nil` if it's not an nested array of {{type}}.
      def as_2a?(type : {{type}}.class) : Array(Array({{type}}))?
        @raw.as?(Array).try do |arr|
          arr.map do |ele|
            nested_arr = ele.as?(Array) || return
            nested_arr.map do |nested_ele|
              nested_ele.as?({{type}}) || return
            end
          end
        end
      end

      # Returns the enclosed value as an array of {{type}}. Raises
      # `TypeCastError` if it's not an array of {{type}}.
      def as_a(type : {{type}}.class) : Array({{type}})
        @raw.as(Array).map &.as({{type}})
      end

      # Returns the enclosed value as an array of {{type}}, or `nil` if
      # it's not an array of {{type}}.
      def as_a?(type : {{type}}.class) : Array({{type}})?
        @raw.as?(Array).try &.map { |ele| ele.as?({{type}}) || return }
      end
    {% end %}

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

  # :ditto:
  def []=(key : String, value : Array) : Array
    @data[key] = Any.new(value)
    value
  end

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
