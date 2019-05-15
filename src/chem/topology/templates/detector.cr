module Chem::Topology::Templates
  class Detector
    CTER_T = Chem::Topology::Templates::Builder.build do
      name "C-ter"
      code "CTER"
      symbol 'c'
      main "CA-C=O"
      branch "C-OXT"
    end
    NTER_T = Chem::Topology::Templates::Builder.build do
      name "N-ter"
      code "NTER"
      symbol 'n'
      main "CA-N"
    end

    def initialize(@templates : Array(Residue))
      @atom_table = {} of Atom | AtomType => String
      @atom_type_map = {} of Atom => String
      @mapped_atoms = Set(Atom).new
      compute_atom_descriptions @templates
      compute_atom_descriptions [CTER_T, NTER_T]
    end

    def each_match(structure : Structure, &block : Residue, Hash(Atom, String) ->)
      reset_cache
      compute_atom_descriptions structure

      n_atoms = structure.size
      @templates.each do |res_t|
        next if (n_atoms - @mapped_atoms.size) < res_t.size
        next unless root = res_t.root
        each_match res_t, root, structure do |res_t, idxs|
          yield res_t, idxs
        end
      end
    end

    private def compute_atom_descriptions(structure : Structure)
      structure.each_atom do |atom|
        @atom_table[atom] = String.build do |io|
          io << atom.element.symbol
          atom.bonded_atoms.map(&.element.symbol).sort!.join "", io
        end
      end
    end

    private def compute_atom_descriptions(res_types : Array(Residue))
      res_types.each do |res_t|
        res_t.each_atom_type do |atom_t|
          @atom_table[atom_t] = String.build do |io|
            bonded_atoms = res_t.bonded_atoms(atom_t)
            if (bond = res_t.link_bond) && bond.includes?(atom_t)
              bonded_atoms << res_t[bond.other(atom_t)]
            end

            io << atom_t.element.symbol
            bonded_atoms.map(&.element.symbol).sort!.join "", io
          end
        end
      end
    end

    private def each_match(res_t : Residue,
                           atom_type : AtomType,
                           structure : Structure,
                           &block : Residue, Hash(Atom, String) ->)
      structure.each_atom do |atom|
        next if mapped?(atom)
        match res_t, atom_type, atom
        if res_t.kind.protein? && @atom_type_map.has_value?("CA")
          extend_match CTER_T, CTER_T["C"], @atom_type_map.key_for("CA")
          extend_match NTER_T, NTER_T["N"], @atom_type_map.key_for("CA")
        end
        if @atom_type_map.size >= res_t.atom_count
          @atom_type_map.each_key { |atom| @mapped_atoms << atom }
          yield res_t, @atom_type_map
        end
        @atom_type_map.clear
      end
    end

    private def extend_match(res_t : Residue, atom_t : AtomType, atom : Atom)
      atom.bonded_atoms.each do |other|
        next if mapped?(other) || @atom_table[other] != @atom_table[atom_t]
        match res_t, atom_t, other
      end
    end

    private def mapped?(atom : Atom) : Bool
      @mapped_atoms.includes?(atom) || @atom_type_map.has_key?(atom)
    end

    private def match(res_t : Residue, atom_t : AtomType, atom : Atom)
      return if mapped?(atom) || @atom_table[atom] != @atom_table[atom_t]
      @atom_type_map[atom] = atom_t.name
      res_t.bonded_atoms(atom_t).each do |other_t|
        atom.bonded_atoms.each do |other|
          match res_t, other_t, other
        end
      end
    end

    private def reset_cache : Nil
      @atom_table.reject! { |k, _| k.is_a? Atom }
      @atom_type_map.clear
      @mapped_atoms.clear
    end
  end
end
