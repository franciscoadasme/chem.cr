class Array(T)
  # Returns the entries encoded in the specified file. The file format
  # is chosen based on the filename (see `Chem::Format#from_filename`).
  # Raises `ArgumentError` if the file format cannot be determined.
  def self.read(path : Path | String) : self
    read path, Chem::Format.from_filename(path)
  end

  # Returns the entries encoded in the specified file using *format*.
  # Raises `ArgumentError` if *format* is invalid.
  def self.read(input : IO | Path | String, format : String) : self
    read input, Chem::Format.parse(format)
  end

  # Returns the entries encoded in the specified file using *format*.
  # Uses `Chem::Format#reader` to get the reader on runtime.
  def self.read(input : IO | Path | String, format : Chem::Format) : self
    format.reader(self).open(input) do |reader|
      Array(T).new.tap do |ary|
        reader.each { |obj| ary << obj }
      end
    end
  end

  def sort(range : Range(Int, Int)) : self
    dup.sort! range
  end

  def sort(range : Range(Int, Int), &block : T, T -> Int32?) : self
    dup.sort! range, &block
  end

  def sort!(range : Range(Int, Int)) : self
    start, count = Indexable.range_to_index_and_count(range, size) || raise IndexError.new
    raise IndexError.new if start >= size
    count = Math.min count, size - start
    Slice.new(to_unsafe + start, count).sort! if count > 1
    self
  end

  def sort!(range : Range(Int, Int), &block : T, T -> Int32?) : self
    start, count = Indexable.range_to_index_and_count(range, size) || raise IndexError.new
    raise IndexError.new if start >= size
    count = Math.min count, size - start
    Slice.new(to_unsafe + start, count).sort! &block if count > 1
    self
  end

  # Writes the elements to the specified file. The file format is chosen
  # based on the filename (see `Chem::Format#from_filename`). Raises
  # `ArgumentError` if the file format cannot be determined.
  def write(path : Path | String) : Nil
    write path, Chem::Format.from_filename(path)
  end

  # Writes the elements to *output* using *format*. Raises
  # `ArgumentError` if *format* is invalid.
  def write(output : IO | Path | String, format : String) : Nil
    write output, Chem::Format.parse(format)
  end

  # Writes the elements to *output* using *format*. Uses
  # `Chem::Format#writer` to get the writer on runtime.
  def write(output : IO | Path | String, format : Chem::Format) : Nil
    format.writer(typeof(self)).open(output, total_entries: size) do |writer|
      each do |obj|
        writer << obj
      end
    end
  end
end
