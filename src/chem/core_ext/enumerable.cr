module Enumerable(T)
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
