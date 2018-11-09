require "../topology/templates/all"
require "./helpers"
require "./record"
require "./record_iterator"

module Chem::PDB
  class Parser
    private alias BondTable = Hash(Tuple(Int32, Int32), Int32)

    private alias ChainId = Tuple(UInt64, Char?)          # model, ch
    private alias ResidueId = Tuple(UInt64, Int32, Char?) # ch, num, inscode

    @pdb_expt : Protein::Experiment?
    @pdb_has_hydrogens = false
    @pdb_lattice : Lattice?
    @pdb_models = 1
    @pdb_seq : Protein::Sequence?
    @pdb_title = ""

    @atoms = {} of Int32 => Atom
    @chains = {} of ChainId => Chain
    @residues = {} of ResidueId => Residue
    @segments = [] of SecondaryStructureSegment
    @use_hex_numbers = {:atom_serial => false, :residue_number => false}

    private def assign_bonds(bonds : BondTable, to system : System)
      bonds.each do |serials, order|
        index, other = serials
        @atoms[index].bonds.add @atoms[other], order
      end
    end

    private def assign_secondary_structure(to sys : System)
      chains = sys.chains
      @segments.each do |seg|
        next unless chain = chains[seg.chain]?
        chain.each_residue.select { |res| res.number.within? seg.range }.each do |res|
          res.secondary_structure = seg.kind
        end
      end
    end

    private def guess_atom_serial(prev_atom : Atom?) : Int32
      prev_atom ? prev_atom.serial + 1 : Int32::MIN
    end

    private def guess_residue_number(prev_residue : Residue?, resname : String) : Int32
      return Int32::MIN unless prev_residue

      next_number = prev_residue.number
      if prev_residue.name == resname
        if template = Topology::Templates[resname]?
          count = template.atom_count include_hydrogens: @pdb_has_hydrogens
          next_number += 1 unless prev_residue.atoms.size < count
        end
      else
        next_number += 1
      end
      next_number
    end

    private def make_system : System
      sys = System.new
      sys.experiment = @pdb_expt
      sys.lattice = @pdb_lattice
      sys.sequence = @pdb_seq
      sys.title = @pdb_title
      sys
    end

    def parse(io : ::IO, models : Enumerable(Int32)? = nil) : Array(System)
      iter = Record::Iterator.new io
      parse_header iter
      systems = parse_models(iter, models || (1..@pdb_models).to_a)
      bonds = parse_bonds iter
      systems.each do |sys|
        assign_bonds bonds, to: sys
        assign_secondary_structure to: sys
      end
      systems
    end

    private def parse_atom(residue : Residue, prev_atom : Atom?, rec : Record) : Atom
      atom = Atom.new \
        name: rec[12..15].delete(' '),
        serial: parse_atom_serial(rec[6..10]) || guess_atom_serial(prev_atom),
        coords: Spatial::Vector.new(rec[30..37].to_f, rec[38..45].to_f, rec[46..53].to_f),
        residue: residue,
        alt_loc: rec[16]?,
        element: (symbol = rec[76..77]?) ? PeriodicTable[symbol.lstrip]? : nil,
        charge: rec[78..79]?.try(&.reverse.to_i?) || 0,
        occupancy: rec[54..59].to_f,
        temperature_factor: rec[60..65].to_f
      residue << atom
      atom
    end

    private def parse_atom_serial(str : String) : Int32?
      number = str.to_i? base: @use_hex_numbers[:atom_serial] ? 16 : 10
      @use_hex_numbers[:atom_serial] = number >= 99999 if number
      number
    end

    private def parse_bonds(iter : Record::Iterator) : BondTable
      BondTable.new(default_value: 0).tap do |bonds|
        iter.each do |rec|
          case rec.name
          when "conect"
            serial = rec[6..10].to_i
            {11..15, 16..20, 21..25, 26..30}.each do |range|
              if other = rec[range]?.try(&.to_i)
                next if bonds.has_key?({other, serial}) # skip redundant bonds
                bonds[{serial, other}] += 1             # parse duplicates as bond order
              else
                break # there are no more indices to read
              end
            end
          else
            Iterator.stop
          end
        end
      end
    end

    private def parse_chain(sys : System, prev_chain : Chain?, rec : Record) : Chain
      chain_id = rec[21]
      key = {sys.object_id, chain_id}
      @chains[key] ||= begin
        sys << (chain = Chain.new chain_id, sys)
        chain
      end
    end

    private def parse_header(iter : Record::Iterator)
      expt_b = ExperimentBuilder.new
      iter.each do |rec|
        case rec.name
        when "atom", "hetatm", "model" then Iterator.stop
        when "cryst1"                  then @pdb_lattice = parse_lattice rec
        when "helix"                   then @segments << parse_helix rec
        when "nummdl"                  then @pdb_models = rec[10..13].to_i
        when "seqres"                  then @pdb_seq = parse_sequence iter.back
        when "sheet"                   then @segments << parse_sheet rec
        when "expdta"
          expt_b.kind = Protein::Experiment::Kind.parse(rec[10..79].delete "- ")
        when "header"
          expt_b.deposition_date = Time.parse_utc rec[50..58], "%d-%^b-%y"
          expt_b.pdb_accession = rec[62..65].downcase
        when "jrnl"
          case rec[12..15].delete(' ').downcase
          when "doi"
            expt_b.doi = rec[19..79].delete ' '
          end
        when "remark"
          next if rec[10..79].blank? # skip remark first line
          case rec[7..9].to_i
          when 2
            expt_b.resolution = rec[23..29].to_f?
          end
        when "title"
          @pdb_title += rec[10..79].rstrip.squeeze ' '
          expt_b.title = @pdb_title
        end
      end
      @pdb_expt = expt_b.build?
      @pdb_title = @pdb_expt.try(&.pdb_accession) || @pdb_title
    end

    private def parse_helix(rec : Record)
      SecondaryStructureSegment.new \
        kind: Protein::SecondaryStructure.from_value(rec[38..39].to_i),
        chain: rec[19],
        range: rec[21..24].to_i..rec[33..36].to_i
    end

    private def parse_lattice(rec : Record)
      @lattice = Lattice.new \
        size: {rec[6..14].to_f, rec[15..23].to_f, rec[24..32].to_f},
        angles: {rec[33..39].to_f, rec[40..46].to_f, rec[47..53].to_f},
        space_group: rec[55..65].rstrip
    end

    private def parse_model(iter : Record::Iterator, system : System)
      chain, residue, atom = nil, nil, nil
      iter.each do |rec|
        case rec.name
        when "atom", "hetatm"
          chain = parse_chain system, chain, rec
          residue = parse_residue chain, residue, rec
          atom = parse_atom residue, atom, rec
          @atoms[atom.serial] = atom
          @pdb_has_hydrogens = true if atom.element.hydrogen?
        when "anisou", "ter"
          next
        else
          Iterator.stop
        end
      end
    end

    private def parse_models(iter : Record::Iterator,
                             serials : Enumerable(Int32)) : Array(System)
      model = serials.first
      system = make_system
      Array(System).new(serials.size).tap do |models|
        iter.each do |rec|
          case rec.name
          when "atom", "hetatm"
            next unless serials.includes? model
            parse_model iter.back, system
          when "endmdl"
            models << system if serials.includes? model
          when "model"
            model = rec[10..13].to_i
            system = make_system unless system.empty?
          else
            Iterator.stop
          end
        end
        models << system if models.empty?
      end
    end

    private def parse_residue(chain : Chain,
                              prev_res : Residue?,
                              rec : Record) : Residue
      name = rec[17..20].delete ' '
      number = parse_residue_number(rec[22..25]) || guess_residue_number(prev_res, name)
      ins_code = rec[26]?

      key = {chain.object_id, number, ins_code}
      @residues[key] ||= begin
        chain << (residue = Residue.new name, number, ins_code, chain)
        residue
      end
    end

    private def parse_residue_number(str : String) : Int32?
      base = @use_hex_numbers[:residue_number] && str != "9999" ? 16 : 10
      number = str.to_i? base
      @use_hex_numbers[:residue_number] = number >= 9999 if number
      number
    end

    private def parse_sequence(iter : Record::Iterator) : Protein::Sequence
      Protein::Sequence.build do |aminoacids|
        iter.each do |rec|
          case rec.name
          when "seqres"
            rec[19..79].split.each { |name| aminoacids << Protein::AminoAcid[name] }
          else
            Iterator.stop
          end
        end
      end
    end

    private def parse_sheet(rec : Record) : SecondaryStructureSegment
      SecondaryStructureSegment.new \
        kind: Protein::SecondaryStructure.from_value(rec[38..39].to_i + 100),
        chain: rec[21],
        range: rec[22..25].to_i..rec[33..36].to_i
    end
  end
end
