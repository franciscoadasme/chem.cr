require "./chem/core_ext/**"

require "./chem/linalg"
require "./chem/spatial"

require "./chem/core/bias"
require "./chem/core/bond"
require "./chem/core/bond_array"
require "./chem/core/element"
require "./chem/core/periodic_table"
require "./chem/core/atom"
require "./chem/core/atom_collection"
require "./chem/core/residue"
require "./chem/core/residue_collection"
require "./chem/core/chain"
require "./chem/core/chain_collection"
require "./chem/core/array_view"
require "./chem/core/atom_view"
require "./chem/core/residue_view"
require "./chem/core/chain_view"
require "./chem/core/lattice"
require "./chem/core/structure"
require "./chem/core/structure/*"

require "./chem/protein"
require "./chem/topology"

require "./chem/register_format"
require "./chem/format"
require "./chem/format_reader"
require "./chem/format_writer"
require "./chem/formats/**"

module Chem
  class Error < Exception; end

  class ParseException < Exception
    @line : String?
    @location : Tuple(Int32, Int32, Int32)?

    def initialize(@message : String); end

    def initialize(@message : String,
                   @path : String?,
                   @line : String,
                   @location : Tuple(Int32, Int32, Int32))
    end

    def inspect_with_location : String
      String.build do |io|
        inspect_with_location io
      end
    end

    def inspect_with_location(io : IO) : Nil
      io << "Found a parsing issue"
      io << " in " << @path if @path
      io << ':' << '\n' << '\n'
      if location = @location
        line_number, column_number, cursor_size = location
        io << ' ' << line_number << " | " << @line << '\n'
        (column_number + line_number.to_s.bytesize + 4).times { io << ' ' }
        cursor_size.times { io << '^' }
        io << '\n'
      end
      io << "Error: " << @message
      io.flush
    end
  end
end
