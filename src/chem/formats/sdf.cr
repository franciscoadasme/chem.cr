@[Chem::RegisterFormat(ext: %w(.sdf), module_api: true)]
module Chem::SDF
  # Yields each structure in *io*.
  def self.each(io : IO, & : Structure ->) : Nil
    loop do
      begin
        yield read(io)
      rescue IO::EOFError
        break
      end
    end
  end

  # :ditto:
  def self.each(path : Path | String, & : Structure ->) : Nil
    File.open(path) do |file|
      each(file) do |struc|
        yield struc
      end
    end
  end

  # Returns the next structure from *io*.
  # Use `read_all` or `each` for multiple.
  def self.read(io : IO) : Structure
    struc = Mol.read(io)

    pull = PullParser.new(io)
    while pull.consume_line.next_s? == ">"
      key = pull.expect_next(/<\w+>/).str.lchop('<').rchop('>').underscore
      value = pull.consume_line.line.presence || pull.error "Expected a data value for field #{key}"
      if value.size == 200 # may be split into multiple lines
        while pull.consume_line.line.presence
          value += pull.line || ""
        end
      elsif !pull.consume_line.line.try(&.blank?)
        pull.error "Expected blank line after field #{key}"
      end
      struc.metadata[key] = value.to_i? || value.to_f? || value
    end
    pull.expect("$$$$")

    struc
  end

  # :ditto:
  def self.read(path : Path | String) : Structure
    File.open(path) do |file|
      read(file)
    end
  end

  # Returns all structures in *io*.
  def self.read_all(io : IO) : Array(Structure)
    ary = [] of Structure
    each(io) do |struc|
      ary << struc
    end
    ary
  end

  # :ditto:
  def self.read_all(path : Path | String) : Array(Structure)
    File.open(path) do |file|
      read_all(file)
    end
  end

  # Writes one or more structures to *io*.
  #
  # The CTAB format is specified via *variant*: V2000 (legacy) or V3000.
  def self.write(
    io : IO,
    struc : Structure,
    variant : Mol::Variant = :v2000,
  ) : Nil
    Mol.write io, struc, variant
    struc.metadata.each do |key, value|
      io.puts "> <#{key.underscore.upcase}>"
      if str = value.as_s?
        str.scan(/.{1,200}( |$)/).each do |match|
          io.puts match[0]
        end
      else
        io.puts value
      end
      io.puts
    end
    io.puts "$$$$"
  end

  # :ditto:
  def self.write(path : Path | String, struc : Structure, variant : Mol::Variant = :v2000) : Nil
    File.open(path, "w") do |file|
      write(file, struc, variant)
    end
  end

  # :ditto:
  def self.write(io : IO, structures : Enumerable(Structure), variant : Mol::Variant = :v2000) : Nil
    structures.each do |struc|
      write(io, struc, variant)
    end
  end

  # :ditto:
  def self.write(path : Path | String, structures : Enumerable(Structure), variant : Mol::Variant = :v2000) : Nil
    File.open(path, "w") do |file|
      write(file, structures, variant)
    end
  end
end
