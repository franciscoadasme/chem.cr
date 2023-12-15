module Indexable(T)
  # Returns a tuple with the elements at the given indexes. Raises
  # `IndexError` is any index is out of bounds.
  #
  # ```
  # arr = (0..9).map(&.**(2)) # => [0, 1, 4, 9, 16, 25, 36, 49, 64, 81]
  # arr[{2, 5, 9}]            # => {4, 25, 81}
  # arr[{2, 15, 9}]           # raises IndexError
  # ```
  def [](idxs : Tuple) : Tuple
    idxs.map { |i| self[i] }
  end

  # Returns a tuple with the elements at the given indexes. Raises
  # `IndexError` is any index is out of bounds.
  #
  # ```
  # arr = (0..9).map(&.**(2)) # => [0, 1, 4, 9, 16, 25, 36, 49, 64, 81]
  # arr[2, 5, 9]              # => {4, 25, 81}
  # arr[2, 15, 9]             # raises IndexError
  # ```
  def [](*idxs : Int) : Tuple
    idxs.map { |i| self[i] }
  end

  # Returns an array with the elements at the given indexes. Raises
  # `IndexError` is any index is out of bounds.
  #
  # ```
  # arr = (0..9).map(&.**(2)) # => [0, 1, 4, 9, 16, 25, 36, 49, 64, 81]
  # arr[[2, 5, 9]]            # => [4, 25, 8]
  # arr[[2, 15, 9]]           # raises IndexError
  # ```
  def [](idxs : Enumerable(Int)) : Array(T)
    idxs.map { |i| self[i] }
  end

  # Prints the elements in the collection as a sentence to *io*. How
  # each element is printed is controlled by the given block.
  #
  # The output depends on the number of elements in the collection:
  #
  # - If there are three or more elements, all but the tail element in
  #   the collection are joined by *separator*, and the tail element is
  #   joined by *tail_separator*.
  # - If there are two elements, these are joined by *pair_separator*.
  # - If there is one element, it is printed to *io* without any
  #   separator.
  # - If the collection is empty, nothing is printed.
  #
  # ```
  # [1, 2, 3].sentence(STDOUT, "-", tail_separator: "-or-") { |e, io| io << "(#{e})" }
  # ```
  #
  # Prints:
  #
  # ```text
  # (1)-(2)-or-(3)
  # ```
  def sentence(
    io : IO,
    separator : String = ", ",
    *,
    pair_separator : String = " and ",
    tail_separator : String = ", and ",
    & : T, IO ->
  ) : Nil
    case size
    when 0
      io << ""
    when 1
      yield unsafe_fetch(0), io
    when 2
      yield unsafe_fetch(0), io
      io << pair_separator
      yield unsafe_fetch(1), io
    else
      each_with_index do |elem, i|
        io << separator if 0 < i < size - 1
        io << tail_separator if i == size - 1
        yield elem, io
      end
    end
  end

  # Prints the elements in the collection as a sentence to *io*.
  #
  # The output depends on the number of elements in the collection:
  #
  # - If there are three or more elements, all but the tail element in
  #   the collection are joined by *separator*, and the tail element is
  #   joined by *tail_separator*.
  # - If there are two elements, these are joined by *pair_separator*.
  # - If there is one element, it is printed to *io* without any
  #   separator.
  # - If the collection is empty, nothing is printed.
  #
  # ```
  # [1, 2, 3].sentence(STDOUT, "-", tail_separator: "-or-")
  # ```
  #
  # Prints:
  #
  # ```text
  # 1-2-or-3
  # ```
  def sentence(
    io : IO,
    separator : String = ", ",
    *,
    pair_separator : String = " and ",
    tail_separator : String = ", and "
  ) : Nil
    sentence(
      io,
      separator,
      tail_separator: tail_separator,
      pair_separator: pair_separator) do |elem, io|
      elem.to_s(io)
    end
  end

  # Returns a `String` by concatenating the elements in the collection
  # as a sentence. How each element is printed is controlled by the
  # given block.
  #
  # The string representation depends on the number of elements in the
  # collection:
  #
  # - If there are three or more elements, all but the tail element in
  #   the collection are joined by *separator*, and the tail element is
  #   joined by *tail_separator*.
  # - If there are two elements, these are joined by *pair_separator*.
  # - If there is one element, it is returned as is.
  # - If the collection is empty, an empty string is returned.
  #
  # ```
  # [1, 2, 3].sentence { |e| "(#{e})" }                              # => "(1), (2), and (3)"
  # [1, 2, 3].sentence("-", tail_separator: "-or-") { |e| "(#{e})" } # => "(1)-(2)-or-(3)"
  # ```
  def sentence(
    separator : String = ", ",
    *,
    pair_separator : String = " and ",
    tail_separator : String = ", and ",
    & : T ->
  ) : String
    String.build do |io|
      sentence(
        io,
        separator,
        pair_separator: pair_separator,
        tail_separator: tail_separator) do |elem|
        io << yield elem
      end
    end
  end

  # Returns a `String` by concatenating the elements in the collection
  # as a sentence.
  #
  # The string representation depends on the number of elements in the
  # collection:
  #
  # - If there are three or more elements, all but the tail element in
  #   the collection are joined by *separator*, and the tail element is
  #   joined by *tail_separator*.
  # - If there are two elements, these are joined by *pair_separator*.
  # - If there is one element, it is returned as is.
  # - If the collection is empty, an empty string is returned.
  #
  # ```
  # ([] of Int32).sentence                          # => ""
  # [1].sentence                                    # => "1"
  # [1, 2].sentence                                 # => "1 and 2"
  # [1, 2].sentence(pair_separator: "-or-")         # => "1-or-2"
  # [1, 2, 3].sentence                              # => "1, 2, and 3"
  # [1, 2, 3].sentence("-", tail_separator: "-or-") # => "1-2-or-3"
  # ```
  def sentence(
    separator : String = ", ",
    *,
    pair_separator : String = " and ",
    tail_separator : String = ", and "
  ) : String
    String.build do |io|
      sentence(
        io,
        separator,
        pair_separator: pair_separator,
        tail_separator: tail_separator)
    end
  end
end
