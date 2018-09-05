module Chem
  class Configuration
    alias ValueType = Int32 | Float64 | Bool | String

    @options = {} of String => ValueType

    def initialize
    end

    def initialize(options : Hash(String, ValueType))
      @options = options.dup
    end

    def [](name : String) : ValueType
      self[name]? || raise "unknown option: #{name}"
    end

    def []?(name : String) : ValueType?
      @options[name]?
    end

    def []=(name : String, value : ValueType) : Nil
      @options[name] = value
    end
  end
end
