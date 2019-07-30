module Chem
  class Atom
    def to_pdb(pdb : PDB::Builder) : Nil
      pdb.string (residue.protein? ? "ATOM" : "HETATM"), width: 6
      pdb.number (pdb.renumber? ? pdb.next_index : serial), width: 5
      pdb.space
      pdb.string name.ljust(3).rjust(4)
      pdb.string (pdb.alternate_locations? ? alt_loc : ' ') || ' '
      pdb.string residue.name, width: 3
      pdb.space
      pdb.string chain.id
      pdb.number residue.number, width: 4
      pdb.string residue.insertion_code || ' '
      pdb.space 3
      coords.to_pdb pdb
      pdb.number (pdb.alternate_locations? ? occupancy : 1.0), precision: 2, width: 6
      pdb.number temperature_factor, precision: 2, width: 6
      pdb.space 10
      element.to_pdb pdb
      if formal_charge != 0
        pdb.string sprintf("%+d", formal_charge).reverse
      else
        pdb.space 2
      end
      pdb.newline
    end
  end

  module AtomCollection
    def to_pdb(pdb : PDB::Builder) : Nil
      pdb.bonds = bonds if pdb.bonds?
      pdb.object do
        each_atom &.to_pdb(pdb)
      end
    end
  end

  class PeriodicTable::Element
    def to_pdb(pdb : PDB::Builder) : Nil
      pdb.string symbol, alignment: :right, width: 2
    end
  end

  class Lattice
    def to_pdb(pdb : PDB::Builder) : Nil
      pdb.string "CRYST1"
      pdb.number a.size, precision: 3, width: 9
      pdb.number b.size, precision: 3, width: 9
      pdb.number c.size, precision: 3, width: 9
      pdb.number alpha, precision: 2, width: 7
      pdb.number beta, precision: 2, width: 7
      pdb.number gamma, precision: 2, width: 7
      pdb.space
      pdb.string "P 1", width: 11 # default space group
      pdb.number 1, width: 4      # default Z value
      pdb.space 10
      pdb.newline
    end
  end

  struct Protein::Experiment
    def to_pdb(pdb : PDB::Builder) : Nil
      pdb.string "HEADER"
      pdb.space 4
      pdb.space 40
      deposition_date.to_pdb pdb
      pdb.space 3
      pdb.string pdb_accession.upcase
      pdb.space 14
      pdb.newline

      pdb.title title

      method = kind.to_s.underscore.upcase.gsub('_', ' ').gsub "X RAY", "X-RAY"
      pdb.string "EXPDTA"
      pdb.space 4
      pdb.string method, width: 70
      pdb.newline

      if doi = @doi
        pdb.string "JRNL", width: 6
        pdb.space 6
        pdb.string "DOI", width: 4
        pdb.space 3
        pdb.string doi, width: 61
        pdb.newline
      end
    end
  end

  class Structure
    def to_pdb(pdb : PDB::Builder) : Nil
      pdb.bonds = bonds if pdb.bonds?
      pdb.experiment = experiment
      pdb.title = title

      prev_chain = nil
      prev_res = nil
      pdb.object do
        lattice.try &.to_pdb(pdb)
        each_atom do |atom|
          atom.to_pdb pdb
          prev_res = atom.residue
          pdb.ter prev_res if prev_chain && atom.chain != prev_chain && prev_res.polymer?
          prev_chain = atom.chain
        end
        pdb.ter prev_res if prev_res && prev_res.polymer?
      end
    end
  end

  struct Spatial::Vector
    def to_pdb(pdb : PDB::Builder) : Nil
      pdb.number x, precision: 3, width: 8
      pdb.number y, precision: 3, width: 8
      pdb.number z, precision: 3, width: 8
    end
  end
end

struct Time
  def to_pdb(pdb : Chem::PDB::Builder) : Nil
    pdb.string to_s("%d-%^b-%y"), width: 9
  end
end
