require "./utils"

@[Chem::RegisterFormat(names: %w(LOCPOT*), module_api: true)]
module Chem::VASP::Locpot
  # Returns the local potential from *io*.
  def self.read(io : IO | Path | String) : Spatial::Grid
    Reader.open(io) do |r|
      r.read_entry
    end
  end

  # Returns the grid information from *io* without reading the data.
  def self.read_info(io : IO | Path | String) : Spatial::Grid::Info
    Reader.open(io) do |r|
      r.read_header
    end
  end

  # Returns the structure from *io* without reading the data.
  # Equivalent to `Poscar.read`.
  def self.read_structure(io : IO | Path | String) : Structure
    Reader.open(io) do |r|
      r.read_attached
    end
  end

  # Writes a grid to *io*.
  #
  # The structure is written in the header.
  # Raises `ArgumentError` if the structure's unit cell does not match the grid bounds.
  def self.write(
    io : IO | Path | String,
    grid : Spatial::Grid,
    structure : Structure,
  ) : Nil
    Writer.open(io, structure: structure) do |w|
      w << grid
    end
  end

  class Reader
    include FormatReader(Spatial::Grid)
    include FormatReader::Headed(Spatial::Grid::Info)
    include FormatReader::Attached(Structure)
    include GridReader

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new(@io)
    end

    protected def decode_entry : Spatial::Grid
      read_array read_header, &.itself
    end
  end

  class Writer
    include FormatWriter(Spatial::Grid)
    include GridWriter

    protected def encode_entry(obj : Spatial::Grid) : Nil
      incompatible_expcetion if (cell = @structure.cell?) && cell.size != obj.bounds.size
      write_header
      write_array(obj, &.itself)
    end
  end
end
