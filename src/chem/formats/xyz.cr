# The XYZ module provides capabilities for reading and writing in the
# XYZ file format.
#
# The XYZ file format is a text-based free format that encodes molecular
# structure. There is no formal standard specification, but the most
# common format is as follows:
#
# ```text
# <number of atoms>
# comment line
# <element> <X> <Y> <Z>
# ...
# ```
#
# Elements are specified by their symbols, and atom coordinates are
# free-form. The units are expected in ångströms. Additional columns may
# exist, but these are ignored. A XYZ file can hold multiple blocks,
# where each one of them is decoded into a `Structure` instance. Further
# details can be found at the [XYZ file format
# specification](http://openbabel.org/wiki/XYZ_%28format%29) of
# OpenBabel.
#
# Registered file extensions for XYZ are: `.xyz`.
#
# ### Reading XYZ files
#
# The `XYZ::Reader` class reads XYZ entries sequentially from an `IO` or
# file. Use either the `#each` method to yield every entry or
# `#read_next` method to read the next entry only.
#
# ```
# XYZ::Reader.open("/path/to/xyz") do |reader|
#   reader.each do |structure|
#     ...
#   end
#
#   # or
#
#   while structure = reader.read_next
#     ...
#   end
# end
# ```
#
# Alternatively, use the convenience `Structure.from_xyz` and
# `Array.from_xyz` methods to read the first or all entries in a XYZ
# file, respectively.
#
# ```
# Structure.from_xyz "/path/to/xyz" # => <Structure ...>
# # or
# Array(Structure).from_xyz "/path/to/xyz" # => [<Structure ...>, ...]
# ```
#
# Similarly, the general `Structure#read` method can be used to read a
# XYZ file, but the file format is determined on runtime.
#
# ### Writing XYZ files
#
# The `XYZ::Writer` class writes XYZ entries sequentially to an `IO` or
# file. Use the `#<<` method to write an instance of a compatible type.
# It can be called multiple times.
#
# ```
# XYZ::Writer.open("/path/to/xyz") do |writer|
#   writer.write structure1
#   writer.write structure2
#   ...
# end
# ```
#
# Alternatively, use the convenience `Structure#to_xyz` or
# `Array#to_xyz` methods to write a single or multiple entries to a XYZ
# file.
#
# ```
# structure = Structure.build do |builder|
#   ...
# end
# structure.to_xyz "/path/to/xyz"
#
# # or
#
# [structure1, structure2, ...].to_xyz "/path/to/xyz"
# ```
@[Chem::FileType(ext: %w(xyz))]
module Chem::XYZ
  # Writes entries sequentially to a XYZ file.
  #
  # ```
  # XYZ::Writer.open("/path/to/xyz") do |writer|
  #   writer << structure1
  #   writer << structure2
  #   ...
  # end
  # ```
  class Writer
    include FormatWriter(AtomCollection)
    include MultiFormatWriter(AtomCollection)
    include FormatWriter(Structure)
    include MultiFormatWriter(Structure)

    private def write(atoms : AtomCollection, title : String = "") : Nil
      check_open

      @io.puts atoms.n_atoms
      @io.puts title.gsub(/ *\n */, ' ')
      atoms.each_atom do |atom|
        @io.printf "%-3s%15.5f%15.5f%15.5f\n", atom.element.symbol, atom.x, atom.y, atom.z
      end
    end

    private def write(structure : Structure) : Nil
      write structure, structure.title
    end
  end

  # Reads the entries sequentially in a XYZ file. Use either the `#each`
  # method to yield every entry or `#read_next` method to read the next
  # entry only.
  #
  # ```
  # XYZ::Reader.open("/path/to/xyz") do |reader|
  #   reader.each do |structure|
  #     ...
  #   end
  #
  #   # or
  #
  #   while structure = reader.read_next
  #     ...
  #   end
  # end
  # ```
  class Reader
    include FormatReader(Structure)
    include MultiFormatReader(Structure)
    include TextFormatReader

    # Triggers bond and topology perception after reading. See
    # `Structure::Builder#build` for more information.
    needs guess_topology : Bool = true

    def read_next : Structure?
      check_open
      return if @io.skip_whitespace.eof?
      Structure.build(@guess_topology) do |builder|
        n_atoms = @io.read_int
        @io.skip_line
        builder.title @io.read_line.strip
        n_atoms.times do
          builder.atom PeriodicTable[@io.read_word], @io.read_vector
          @io.skip_line
        end
      end
    end

    def skip : Nil
      check_open
      return if @io.skip_whitespace.eof?
      n_atoms = @io.read_int
      (n_atoms + 2).times { @io.skip_line }
    end
  end
end
