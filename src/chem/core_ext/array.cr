class Array(T)
  def sort(range : Range(Int, Int)) : self
    dup.sort! range
  end

  def sort(range : Range(Int, Int), &block : T, T -> Int32) : self
    dup.sort! range, &block
  end

  def sort!(range : Range(Int, Int)) : self
    start, count = Indexable.range_to_index_and_count range, size
    raise IndexError.new if start >= size
    count = Math.min count, size - start
    Array.intro_sort! @buffer + start, count if count > 1
    self
  end

  def sort!(range : Range(Int, Int), &block : T, T -> Int32) : self
    start, count = Indexable.range_to_index_and_count range, size
    raise IndexError.new if start >= size
    count = Math.min count, size - start
    Array.intro_sort! @buffer + start, count, block if count > 1
    self
  end
end
