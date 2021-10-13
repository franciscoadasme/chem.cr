module Chem
  module ArrayView(T)
    include Indexable(T)

    @items : Array(T)

    def initialize(items : Enumerable(T))
      @items = items.to_a
    end

    delegate size, unsafe_fetch, to: @items

    {% for op in %w(| & + -) %}
      def {{op.id}}(rhs : Array(T) | self) : self
        wrap @items {{op.id}} rhs.to_a
      end
    {% end %}

    def [](range : Range(Int, Int)) : self
      wrap @items[range]
    end

    def [](start : Int, count : Int) : self
      wrap @items[start, count]
    end

    def []?(range : Range(Int, Int)) : self?
      wrap @items[range]?
    end

    def []?(start : Int, count : Int) : self?
      wrap @items[start, count]?
    end

    def chunks(& : T -> U) : Array(Tuple(U, self)) forall U
      @items.chunks { |ele| yield ele }
        .map { |k, v| {k, wrap(v)} }
    end

    def first(count : Int) : self
      wrap @items.first(count)
    end

    def group_by(& : T -> U) : Hash(U, self) forall U
      @items.group_by { |ele| yield ele }
        .transform_values { |ary| wrap(ary) }
    end

    def last(count : Int) : self
      wrap @items.last(count)
    end

    def partition(& : T -> _) : Tuple(self, self)
      @items.partition { |ele| yield ele }
        .map { |ary| wrap(ary) }
    end

    def reject(& : T -> _) : self
      wrap @items.reject { |ele| yield ele }
    end

    def reject(value) : self
      wrap @items.reject(value)
    end

    def reverse : self
      wrap @items.reverse
    end

    def reverse! : self
      @items.reverse!
      self
    end

    def rotate(n : Int = 1) : self
      wrap @items.rotate(n)
    end

    def rotate!(n : Int = 1) : self
      @items.rotate!(n)
      self
    end

    def sample(n : Int, random = Random::DEFAULT) : self
      wrap @items.sample(n, random)
    end

    def select(& : T -> _) : self
      wrap @items.select { |ele| yield ele }
    end

    def select(value) : self
      wrap @items.select(value)
    end

    def shuffle(random = Random::DEFAULT) : self
      wrap @items.shuffle(random)
    end

    def shuffle!(random = Random::DEFAULT) : self
      @items.shuffle!(random)
      self
    end

    def skip(count : Int) : self
      wrap @items.skip(count)
    end

    def skip_while(& : T -> _) : self
      wrap @items.skip_while { |ele| yield ele }
    end

    def sort : self
      wrap @items.sort
    end

    def sort(& : T, T -> Int) : self
      wrap @items.sort { |a, b| yield a, b }
    end

    def sort! : self
      @items.sort!
      self
    end

    def sort!(& : T, T -> Int) : self
      @items.sort! { |a, b| yield a, b }
      self
    end

    def sort_by(& : T -> _) : self
      wrap @items.sort_by { |ele| yield ele }
    end

    def sort_by!(& : T -> _) : self
      @items.sort_by! { |ele| yield ele }
      self
    end

    def take_while(& : T -> _) : self
      wrap @items.take_while { |ele| yield ele }
    end

    def to_a : Array(T)
      @items
    end

    private def wrap(obj : Array(T)) : self
      {{@type}}.new obj
    end
  end
end
