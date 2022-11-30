class Chem::Topology::Detector
  CTER_T = ResidueTemplate.build do
    description "C-ter"
    name "CTER"
    code 'c'
    structure "CA-C(=O)-OXT"
    root "C"
  end
  CHARGED_CTER_T = ResidueTemplate.build do
    description "Charged C-ter"
    name "CTER"
    code 'c'
    structure "CA-C(=O)-[OXT-]"
    root "C"
  end
  NTER_T = ResidueTemplate.build do
    description "N-ter"
    name "NTER"
    code 'n'
    structure "CA-N"
    root "N"
  end
  CHARGED_NTER_T = ResidueTemplate.build do
    description "Charged N-ter"
    name "NTER"
    code 'n'
    structure "CA-[NH3+]"
    root "N"
  end

  @atoms : Set(Atom)
  @templates : Array(ResidueTemplate)

  def initialize(atoms : AtomCollection, templates : Array(ResidueTemplate)? = nil)
    @atoms = Set(Atom).new(atoms.n_atoms).concat atoms.each_atom
    @atom_table = {} of Atom | AtomTemplate => String
    @templates = templates || ResidueTemplate.all_templates
    compute_atom_descriptions @atoms
    compute_atom_descriptions @templates
    compute_atom_descriptions [CTER_T, NTER_T, CHARGED_CTER_T, CHARGED_NTER_T]
  end

  def each_match(& : MatchData ->) : Nil
    atom_map = {} of Atom => String
    @atoms.each do |atom|
      next if mapped?(atom, atom_map)
      @templates.each do |res_t|
        next if @atoms.size < res_t.n_atoms
        if match?(res_t, atom, atom_map)
          yield MatchData.new(res_t, atom_map.invert)
          @atoms.subtract atom_map.each_key
        end
        atom_map.clear
      end
    end
  end

  def matches : Array(MatchData)
    matches = [] of MatchData
    each_match { |match| matches << match }
    matches
  end

  def unmatched_atoms : AtomView
    AtomView.new @atoms.to_a.sort_by!(&.serial)
  end

  private def compute_atom_descriptions(atoms : Enumerable(Atom))
    atoms.each do |atom|
      @atom_table[atom] = String.build do |io|
        io << atom.element.symbol
        atom.bonded_atoms.map(&.element.symbol).sort!.join io, ""
      end
    end
  end

  private def compute_atom_descriptions(res_types : Array(ResidueTemplate))
    res_types.each do |res_t|
      res_t.each_atom_t do |atom_t|
        @atom_table[atom_t] = String.build do |io|
          bonded_atoms = res_t.bonded_atoms(atom_t)
          if (bond = res_t.link_bond) && atom_t.in?(bond)
            bonded_atoms << bond.other(atom_t)
          end

          io << atom_t.element.symbol
          bonded_atoms.map(&.element.symbol).sort!.join io, ""
        end
      end
    end
  end

  private def extend_match(res_t : ResidueTemplate,
                           root : Atom,
                           atom_map : Hash(Atom, String))
    ter_map = {} of Atom => String
    [NTER_T, CHARGED_NTER_T, CTER_T, CHARGED_CTER_T].each do |ter_t|
      root.each_bonded_atom do |other|
        search ter_t, ter_t.root_atom, other, ter_map
      end

      if ter_map.size == ter_t.n_atoms - 4 # ter has an extra CH3
        atom_map.merge! ter_map
        break
      end
      ter_map.clear
    end
  end

  private def mapped?(atom : Atom, atom_map : Hash(Atom, String)) : Bool
    !atom.in?(@atoms) || atom_map.has_key?(atom)
  end

  private def mapped?(atom_t : AtomTemplate, atom_map : Hash(Atom, String)) : Bool
    atom_map.has_value? atom_t.name
  end

  private def match?(res_t : ResidueTemplate,
                     atom : Atom,
                     atom_map : Hash(Atom, String)) : Bool
    search res_t, res_t.root_atom, atom, atom_map
    if res_t.kind.protein? && (root = atom_map.key_for?("CA"))
      extend_match res_t, root, atom_map
    end
    atom_map.size >= res_t.atom_count
  end

  private def match?(atom_t : AtomTemplate, atom : Atom) : Bool
    @atom_table[atom] == @atom_table[atom_t]
  end

  private def search(res_t : ResidueTemplate,
                     atom_t : AtomTemplate,
                     atom : Atom,
                     atom_map : Hash(Atom, String)) : Nil
    return if mapped?(atom, atom_map) || mapped?(atom_t, atom_map)
    return unless match?(atom_t, atom)
    atom_map[atom] = atom_t.name
    res_t.bonded_atoms(atom_t).each do |other_t|
      atom.each_bonded_atom do |other|
        search res_t, other_t, other, atom_map
      end
    end
  end
end
