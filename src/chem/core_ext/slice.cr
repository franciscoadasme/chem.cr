struct Slice(T)
  def concat(other : self) : self
    concat other.to_unsafe, other.size
  end

  def concat(other : self, count : Int) : self
    concat other.to_unsafe, count
  end

  def concat(other : Pointer(T), count : Int) : self
    return self unless count > 0
    new_size = size + count
    ptr = to_unsafe.realloc(new_size)
    (ptr + size).copy_from other, count
    Slice(T).new ptr, new_size
  end

  def skip(& : T -> Bool) : self
    each_with_index do |ele, i|
      return self + i unless yield ele
    end
    Slice(T).empty
  end

  def take_while(& : T -> Bool) : self
    each_with_index do |ele, i|
      return Slice(T).new(@pointer, i) unless yield ele
    end
    self
  end

  def unsafe_index(byte : Int) : Int32?
    if ptr = LibC.memchr(to_unsafe, byte, size)
      (ptr - to_unsafe.as(Void*)).to_i
    end
  end

  def unsafe_index(*bytes : Int) : Int32?
    bytes.each do |byte|
      if i = unsafe_index(byte)
        return i
      end
    end
  end
end
