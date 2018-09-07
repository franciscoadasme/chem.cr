module Iterator(T)
  private class ManyChain(I, T)
    include Iterator(T)

    def initialize(@iterators : Array(I))
      @current_index = 0
    end

    def next
      value = @iterators[@current_index].next
      if value.is_a?(Stop) && @current_index < @iterators.size - 1
        @current_index += 1
        value = self.next
      end
      value
    end

    def rewind
      @iterators.each { |iter| iter.rewind }
      @current_index = 0
    end
  end

  def self.chain(iterators : Array(Iterator(T))) forall T
    ManyChain(typeof(iterators[0]), T).new iterators.dup
  end
end
