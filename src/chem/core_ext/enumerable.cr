module Enumerable(T)
  # Returns the weighted average of the elements in the collection.
  # Raises `EmptyError` if the collection is empty or `ArgumentError` if
  # *weights* has a different number of elements.
  #
  # Expects all element types to respond to `#+` and `#/` methods.
  #
  # ```
  # [1, 2, 3, 4, 5, 6].average((1..6).to_a) # => 4.333333333333333
  # (1..6).average((1..6).to_a)             # => 4.333333333333333
  # ([] of Int32).average([1, 1, 1])        # raises EmptyError
  # (1..6).average([1, 1])                  # raises ArgumentError
  # ```
  #
  # NOTE: This method calls `.additive_identity` on the element type and
  # *weights*' element type to determine the type of the intermediate
  # sum values.
  def average(weights : Indexable(Number))
    average weights, &.itself
  end

  # Returns the weighted average of the results of the passed block for
  # each element in the collection. Raises `EmptyError` if the
  # collection is empty or `ArgumentError` if *weights* has a different
  # number of elements.
  #
  # Expects all element types to respond to `#+` and `#/` methods.
  #
  # ```
  # ["Alice", "Bob"].average([7, 2], &.size)    # => 4.555555555555555
  # ('a'..'z').average((0..25).to_a, &.ord)     # => 4.333333333333333
  # ([] of String).average([1, 1], &.size)      # raises EmptyError
  # ["Alice", "Bob"].average([1, 1, 1], &.size) # raises ArgumentError
  # ```
  #
  # NOTE: This method calls `.additive_identity` on the yielded type and
  # *weights*' element type to determine the type of the intermediate
  # sum values.
  def average(weights : Indexable(Number), & : T -> _)
    memo = typeof(yield Enumerable.element_type(self)).additive_identity
    total = typeof(weights.unsafe_fetch(0)).additive_identity
    if self.responds_to?(:size)
      raise EmptyError.new unless size > 0
      raise ArgumentError.new("Incompatible size") unless weights.size == size
      each_with_index do |ele, i|
        weight = weights.unsafe_fetch(i) # safe since they've the same size
        value = yield ele
        memo += value * weight
        total += weight
      end
    else
      count = 0
      each_with_index do |ele, i|
        weight = weights[i] # cannot ensure that exists
        value = yield ele
        memo += value * weight
        total += weight
        count += 1
      end
      raise ArgumentError.new("Incompatible size") unless count == weights.size
    end
    memo / total
  end

  # Returns the arithmetic mean of the elements in the collection.
  # Raises `EmptyError` if the collection is empty.
  #
  # Expects all element types to respond to `#+` and `#/` methods.
  #
  # ```
  # [1, 2, 3, 4, 5, 6].mean # => 3.5
  # (1..6).mean             # => 3.5
  # ([] of Int32).mean      # raises EmptyError
  # ```
  #
  # NOTE: This method calls `.additive_identity` on the element type to
  # determine the type of the intermediate sum.
  def mean
    mean &.itself
  end

  # Returns the arithmetic mean of the results of the passed block for
  # each element in the collection. Raises `EmptyError` if the
  # collection is empty.
  #
  # Expects all element types to respond to `#+` and `#/` methods.
  #
  # ```
  # ["Alice", "Bob"].mean(&.size) # => 4
  # ('a'..'z').mean(&.ord)        # => 109.5
  # ([] of String).mean(&.size)   # raises EmptyError
  # ```
  #
  # NOTE: This method calls `.additive_identity` on the yielded type to
  # determine the type of the intermediate sum.
  def mean(& : T -> _)
    count = 0
    sum = self.sum do |ele|
      count += 1
      yield ele
    end
    count > 0 ? sum / count : raise EmptyError.new
  end
end
