module Indexable(T)
  def index!(of object, offset : Int = 0) : Int
    index!(offset) { |e| e == object }
  end

  def index!(offset : Int = 0, &block : T -> Bool) : Int
    index(offset, &block) || raise IndexError.new
  end
end
