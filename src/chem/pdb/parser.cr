require "./record"
require "./record/*"

module Chem::PDB
  @[IO::FileType(format: PDB, ext: [:ent, :pdb])]
  class Parser < IO::Parser
    @pdb_bonds = uninitialized Hash(Tuple(Int32, Int32), Int32)
    @pdb_expt : Protein::Experiment?
    @pdb_lattice : Lattice?
    @pdb_seq : Protein::Sequence?
    @pdb_title = ""

    @alt_locs : Hash(Residue, Array(AlternateLocation))?
    @chains : Set(Char)?
    @offsets : Array(Tuple(Int32, Int32))?
    @serial = 0
    @ss_elements = [] of SecondaryStructureElement
    @use_offsets = false

    def initialize(input : ::IO | Path | String,
                   @alt_loc : Char? = nil,
                   chains : Enumerable(Char)? = nil,
                   @het : Bool = true)
      super input
      @iter = Record::Iterator.new @io
      @chains = chains.try &.to_set
      parse_header
      parse_bonds
    end

    private def assign_bonds(builder : Structure::Builder) : Nil
      @pdb_bonds.each do |(i, j), order|
        builder.bond serial_to_index(i), serial_to_index(j), order
      end
    end

    private def assign_secondary_structure(builder : Structure::Builder) : Nil
      @ss_elements.each do |ele|
        builder.secondary_structure ele.start, ele.end, ele.type
      end
    end

    def next : Structure | Iterator::Stop
      @iter.each do |rec|
        case rec.name
        when "atom", "hetatm"
          @iter.back
          return parse_model
        when "end", "master"
          stop
        end
      end
      stop
    end

    def skip_structure : Nil
      @iter.skip "model"
      @iter.each do |rec|
        case rec.name
        when "model", "conect", "master"
          @iter.back
          break
        when "end", "endmdl"
          break
        end
      end
    end

    private def add_offset_at(serial : Int32) : Nil
      offsets << {serial, serial - @serial - 1}
    end

    private def add_sec(type : Protein::SecondaryStructure, i : ResidueId, j : ResidueId)
      @ss_elements << SecondaryStructureElement.new type, i, j
    end

    private def alt_loc(residue : Residue, id : Char, resname : String) : AlternateLocation
      alt_loc = alt_locs[residue].find &.id.==(id)
      alt_locs[residue] << (alt_loc = AlternateLocation.new id, resname) unless alt_loc
      alt_loc
    end

    private def alt_locs : Hash(Residue, Array(AlternateLocation))
      @alt_locs ||= Hash(Residue, Array(AlternateLocation)).new do |hash, key|
        hash[key] = Array(AlternateLocation).new 4
      end
    end

    private def offsets : Array(Tuple(Int32, Int32))
      @offsets ||= [] of Tuple(Int32, Int32)
    end

    private def parse_atom(builder : Structure::Builder, rec : Record) : Nil
      atom = builder.atom \
        rec[12..15].strip,
        Hybrid36.decode(rec[6..10]),
        read_vector(rec),
        element: parse_element(rec, builder.residue.name),
        formal_charge: rec[78..79]?.try(&.reverse.to_i?) || 0,
        occupancy: rec[54..59].to_f,
        temperature_factor: rec[60..65].to_f

      add_offset_at atom.serial if atom.serial - @serial > 1 if @use_offsets
      @serial = atom.serial

      alt_loc(atom.residue, rec[16], rec[17..20].strip) << atom if !@alt_loc && rec[16]?
    end

    private def parse_bonds
      last_pos = @io.pos
      @io.seek 0, ::IO::Seek::End

      @pdb_bonds = Hash(Tuple(Int32, Int32), Int32).new 0
      Record::BackwardIterator.new(@io).each do |rec|
        case rec.name
        when "conect"
          serial = rec[6..10].to_i
          {11..15, 16..20, 21..25, 26..30}.each do |range|
            if other = rec[range]?.try(&.to_i)
              next if serial > other # skip redundant bonds
              @pdb_bonds[{serial, other}] += 1
            else
              break
            end
          end
        when "end", "master"
          next
        else
          ::Iterator.stop
        end
      end

      @use_offsets = !@pdb_bonds.empty?
      @io.pos = last_pos
    end

    private def parse_chain(builder : Structure::Builder, rec : Record) : Nil
      builder.chain rec[21]
    end

    private def parse_element(rec : Record, resname : String) : PeriodicTable::Element?
      case symbol = rec[76..77]?.try(&.lstrip)
      when "D" # deuterium
        PeriodicTable::D
      when "X"
        PeriodicTable::N_or_O if resname == "ASX"
      when String
        PeriodicTable[symbol]?
      end
    end

    private def parse_expt : Nil
      title = ""
      method = Protein::Experiment::Kind::XRayDiffraction
      date = doi = pdbid = resolution = nil

      @iter.each do |rec|
        case rec.name
        when "atom", "hetatm", "cryst1", "model", "seqres", "helix", "sheet"
          ::Iterator.stop
        when "expdta"
          method = Protein::Experiment::Kind.parse rec[10..79].split(';')[0].delete "- "
        when "header"
          date = Time.parse_utc rec[50..58], "%d-%^b-%y"
          pdbid = rec[62..65].downcase
        when "jrnl"
          case rec[12..15].strip.downcase
          when "doi"
            doi = rec[19..79].strip
          end
        when "remark"
          next if rec[10..79].blank? # skip remark first line
          case rec[7..9].to_i
          when 2
            resolution = rec[23..29].to_f?
          end
        when "title"
          title += rec[10..79].rstrip.squeeze ' '
        end
      end

      if date && pdbid
        @pdb_expt = Protein::Experiment.new title, method, resolution, pdbid, date, doi
        @pdb_title = pdbid
      else
        @pdb_title = title
      end
    end

    private def parse_header
      @iter.each do |rec|
        case rec.name
        when "atom", "hetatm", "model" then ::Iterator.stop
        when "cryst1"                  then parse_lattice rec
        when "helix"                   then parse_helix rec
        when "sheet"                   then parse_sheet rec
        when "header", "title", "expdta", "jrnl", "remark"
          @iter.back
          parse_expt
        when "seqres"
          @iter.back
          parse_sequence
        end
      end
    end

    private def parse_helix(rec : Record) : Nil
      kind = case rec[38..39].to_i
             when 1 then Protein::SecondaryStructure::HelixAlpha
             when 3 then Protein::SecondaryStructure::HelixPi
             when 5 then Protein::SecondaryStructure::Helix3_10
             else        Protein::SecondaryStructure::None
             end
      add_sec kind,
        {rec[19], rec[21..24].to_i, rec[25]?},
        {rec[19], rec[33..36].to_i, rec[37]?}
    end

    private def parse_lattice(rec : Record)
      @pdb_lattice = Lattice.new \
        size: {rec[6..14].to_f, rec[15..23].to_f, rec[24..32].to_f},
        angles: {rec[33..39].to_f, rec[40..46].to_f, rec[47..53].to_f}
    end

    private def parse_model : Structure
      Structure.build do |builder|
        title @pdb_title
        lattice @pdb_lattice
        expt @pdb_expt
        seq @pdb_seq

        @iter.skip "model"
        @iter.each do |rec|
          case rec.name
          when "atom", "hetatm"
            next if rec.name == "hetatm" && !read_het?
            next if (chains = @chains) && !chains.includes?(rec[21])
            next if @alt_loc && (alt_loc = rec[16]?) && alt_loc != @alt_loc

            parse_chain builder, rec
            parse_residue builder, rec
            parse_atom builder, rec
          when "anisou", "ter", "sigatm", "siguij"
            next
          when "endmdl"
            break
          else
            ::Iterator.stop
          end
        end

        resolve_alternate_locations unless @alt_loc
        assign_bonds builder
        assign_secondary_structure builder
      end
    end

    private def parse_residue(builder : Structure::Builder, rec : Record) : Nil
      builder.residue rec[17..20].strip, Hybrid36.decode(rec[22..25]), rec[26]?
    end

    private def parse_sequence : Nil
      @pdb_seq = Protein::Sequence.build do |aminoacids|
        @iter.each do |rec|
          case rec.name
          when "seqres"
            next if (chains = @chains) && !chains.includes?(rec[11])
            rec[19..79].split.each { |name| aminoacids << Protein::AminoAcid[name] }
          else
            ::Iterator.stop
          end
        end
      end
    end

    private def parse_sheet(rec : Record) : Nil
      add_sec :beta_strand,
        {rec[21], rec[22..25].to_i, rec[26]?},
        {rec[21], rec[33..36].to_i, rec[37]?}
    end

    private def read_het? : Bool
      @het
    end

    private def read_vector(rec : Record) : Spatial::Vector
      Spatial::Vector.new rec[30..37].to_f, rec[38..45].to_f, rec[46..53].to_f
    end

    private def resolve_alternate_locations : Nil
      return unless table = @alt_locs
      table.each do |residue, alt_locs|
        alt_locs.sort! { |a, b| b.occupancy <=> a.occupancy }
        alt_locs.each(within: 1..) do |alt_loc|
          alt_loc.each_atom do |atom|
            unless @pdb_bonds.empty?
              i = offsets.bsearch_index { |(i, _)| i > atom.serial } || -1
              offsets.insert i, {atom.serial, 1}
            end
            residue.delete atom
          end
        end
        residue.name = alt_locs[0].resname
        residue.reset_cache
      end
      table.clear
    end

    private def serial_to_index(serial : Int32) : Int32
      index = serial - 1
      offsets.each do |loc, offset|
        break if loc > serial
        index -= offset
      end
      index
    end

    private alias ResidueId = Tuple(Char, Int32, Char?)

    private struct AlternateLocation
      getter id : Char
      getter resname : String

      def initialize(@id : Char, @resname : String)
        @atoms = [] of Atom
      end

      def <<(atom : Atom) : self
        @atoms << atom
        self
      end

      def each_atom(&block : Atom ->) : Nil
        @atoms.each do |atom|
          yield atom
        end
      end

      def occupancy : Float64
        @atoms.sum(&.occupancy) / @atoms.size
      end
    end

    private record SecondaryStructureElement,
      type : Protein::SecondaryStructure,
      start : ResidueId,
      end : ResidueId
  end
end
