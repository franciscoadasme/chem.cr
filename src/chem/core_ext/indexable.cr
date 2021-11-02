module Indexable(T)
  def index!(of object, offset : Int = 0) : Int
    index!(offset) { |e| e == object }
  end

  def index!(offset : Int = 0, &block : T -> Bool) : Int
    index(offset, &block) || raise IndexError.new
  end

  def mean : Float64
    {% raise "#mean only works with numbers, not #{@type}" unless @type.type_vars[0] < Number %}
    sum(0) / size
  end

  def mean(& : T -> Number) : Float64
    sum do |ele|
      yield ele
    end / size
  end
end
