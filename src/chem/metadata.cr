class Chem::Metadata
  # Union of possible metadata types.
  alias ValueType = Int32 | Float64 | String | Bool

  include Enumerable({String, ValueType})
  include Iterable({String, ValueType})

  # `Any` wraps a value that can be any of the possible metadata
  # types (`ValueType`). It provides convenient `#as_*` cast methods.
  struct Any
    getter raw : ValueType

    # Creates a new `Any` instance by enclosing the given value.
    def initialize(@raw : ValueType)
    end

    def ==(rhs : self) : Bool
      @raw == rhs.raw
    end

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
      io << self.class.name << '(' << @raw << ')'
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

  def each(& : {String, Type} ->) : Nil
    @data.each do |keyvalue|
      yield keyvalue
    end
  end

  def each : Iterator({String, Type})
    @data.each
  end

  # Empties the `Metadata` and returns it.
  def clear : self
    @data.clear
  end

  # Deletes the key-value pair and returns the value. Returns `nil` if
  # *key* does not exist.
  def delete(key : String) : Any?
    @data.delete(key)
  end

  # Deletes the key-value pair and returns the value. Yields *key* and
  # returns the value returned by the given block if *key* does not
  # exist.
  def delete(key : String, & : String ->) : Any?
    @data.delete(key) { |key| yield key }
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

  # Returns `true` when the metadata contains no key-value pairs, else
  # `false`.
  def fetch? : Bool
    @data.empty?
  end
end
