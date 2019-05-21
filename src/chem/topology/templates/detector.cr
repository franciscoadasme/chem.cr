module Chem::Topology::Templates
  class Detector
    CTER_T = Chem::Topology::Templates::Builder.build do
      name "C-ter"
      code "CTER"
      symbol 'c'
      main "CA-C=O"
      branch "C-OXT"
      root "C"
    end
    CHARGED_CTER_T = Chem::Topology::Templates::Builder.build do
      name "Charged C-ter"
      code "CTER"
      symbol 'c'
      main "CA-C=O"
      branch "C-OXT-"
      root "C"
    end
    NTER_T = Chem::Topology::Templates::Builder.build do
      name "N-ter"
      code "NTER"
      symbol 'n'
      main "CA-N"
      root "N"
    end
    CHARGED_NTER_T = Chem::Topology::Templates::Builder.build do
      name "Charged N-ter"
      code "NTER"
      symbol 'n'
      main "CA-N+"
      root "N"
    end

    def initialize(@templates : Array(Residue))
      @atom_table = {} of Atom | AtomType => String
      @mapped_atoms = Set(Atom).new
      compute_atom_descriptions @templates
      compute_atom_descriptions [CTER_T, NTER_T, CHARGED_CTER_T, CHARGED_NTER_T]
    end

    def each_match(atoms : Enumerable(Atom),
                   &block : Residue, Hash(Atom, String) ->) : Nil
      reset_cache
      compute_atom_descriptions atoms

      atom_map = {} of Atom => String
      atoms.each do |atom|
        next if mapped?(atom, atom_map)
        @templates.each do |res_t|
          next if (atoms.size - @mapped_atoms.size) < res_t.size || res_t.root.nil?
          if match?(res_t, atom, atom_map)
            yield res_t, atom_map
            atom_map.each_key { |atom| @mapped_atoms << atom }
          end
          atom_map.clear
        end
      end
    end

    def each_match(structure : Structure, &block : Residue, Hash(Atom, String) ->) : Nil
      each_match structure.atoms do |res_t, atom_map|
        yield res_t, atom_map
      end
    end

    private def compute_atom_descriptions(atoms : Enumerable(Atom))
      atoms.each do |atom|
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

    private def extend_match(res_t : Residue,
                             root : Atom,
                             atom_map : Hash(Atom, String))
      ter_map = {} of Atom => String
      [NTER_T, CHARGED_NTER_T, CTER_T, CHARGED_CTER_T].each do |ter_t|
        root.bonded_atoms.each do |other|
          search ter_t, ter_t.root.not_nil!, other, ter_map
        end

        if ter_map.size == ter_t.size - 4 # ter has an extra CH3
          atom_map.merge! ter_map
          break
        end
        ter_map.clear
      end
    end

    private def mapped?(atom : Atom, atom_map : Hash(Atom, String)) : Bool
      @mapped_atoms.includes?(atom) || atom_map.has_key?(atom)
    end

    private def mapped?(atom_t : AtomType, atom_map : Hash(Atom, String)) : Bool
      atom_map.has_value? atom_t.name
    end

    private def match?(res_t : Residue,
                       atom : Atom,
                       atom_map : Hash(Atom, String)) : Bool
      search res_t, res_t.root.not_nil!, atom, atom_map
      if res_t.kind.protein? && (root = atom_map.key_for?("CA"))
        extend_match res_t, root, atom_map
      end
      atom_map.size >= res_t.atom_count
    end

    private def match?(atom_t : AtomType, atom : Atom) : Bool
      @atom_table[atom] == @atom_table[atom_t]
    end

    private def reset_cache : Nil
      @atom_table.reject! { |k, _| k.is_a? Atom }
      @mapped_atoms.clear
    end

    private def search(res_t : Residue,
                       atom_t : AtomType,
                       atom : Atom,
                       atom_map : Hash(Atom, String)) : Nil
      return if mapped?(atom, atom_map) || mapped?(atom_t, atom_map)
      return unless match?(atom_t, atom)
      atom_map[atom] = atom_t.name
      res_t.bonded_atoms(atom_t).each do |other_t|
        atom.bonded_atoms.each do |other|
          search res_t, other_t, other, atom_map
        end
      end
    end
  end
end
