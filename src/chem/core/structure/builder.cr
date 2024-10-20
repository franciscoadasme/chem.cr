module Chem
  class Structure::Builder
    @aromatic_bonds : Array(Bond)?
    @atom_number = 0
    @atom_map = {} of Int32 => Atom
    @chain : Chain?
    @residue : Residue?
    @element_counter = Hash(Element, Int32).new(default_value: 0)

    def initialize(
      @guess_bonds : Bool = false,
      @guess_names : Bool = false,
      @use_templates : Bool = false,
      **options
    )
      @structure = Structure.new **options
    end

    def atom(pos : Spatial::Vec3, **options) : Atom
      atom :C, pos, **options
    end

    # Creates an `Atom` of *element* at the given coordinates. Extra
    # named arguments are forwarded to the `Atom` constructor.
    #
    # The atom name will set to the element's symbol followed by the
    # number of atoms with the same element within the current residue.
    #
    # ```
    # structure = Chem::Structure.build do |builder|
    #   builder.residue
    #   builder.atom Chem::PeriodicTable::H, Chem::Spatial::Vec3.zero
    #   builder.atom Chem::PeriodicTable::C, Chem::Spatial::Vec3.zero
    #   builder.atom Chem::PeriodicTable::H, Chem::Spatial::Vec3.zero
    #   builder.atom Chem::PeriodicTable::H, Chem::Spatial::Vec3.zero
    #   builder.atom Chem::PeriodicTable::C, Chem::Spatial::Vec3.zero
    #   builder.residue
    #   builder.atom Chem::PeriodicTable::H, Chem::Spatial::Vec3.zero
    #   builder.atom Chem::PeriodicTable::C, Chem::Spatial::Vec3.zero
    #   builder.atom Chem::PeriodicTable::N, Chem::Spatial::Vec3.zero
    # end
    # structure.atoms.map(&.name) # => ["H1", "C1", "H2", "H3", "C2", "H1", "C1", "N1"]
    # ```
    #
    # Note that the atom names resets on a new residue.
    #
    # WARNING: This method assumes that residues are created in
    # sequence, so calling `#residue` will always create a new residue,
    # not retrieving a preceding one. Otherwise, the order of the atom
    # names will be reset.
    def atom(element : Element | Symbol, pos : Spatial::Vec3, **options) : Atom
      element = PeriodicTable[element.to_s.capitalize] if element.is_a?(Symbol)

      id = (@element_counter[element] += 1)
      atom "#{element.symbol}#{id}", pos, **options.merge(element: element)
    end

    def atom(name : String, pos : Spatial::Vec3, **options) : Atom
      atom name, @atom_number + 1, pos, **options
    end

    def atom(name : String, number : Int32, pos : Spatial::Vec3, **options) : Atom
      atom name, number, pos, Structure.guess_element(name), **options
    end

    def atom(name : String, number : Int32, pos : Spatial::Vec3, element : Element, **options) : Atom
      @atom_number = number
      Atom.new(residue, @atom_number, element, name, pos, **options)
        .tap { |atom| @atom_map[atom.number] = atom }
    end

    def atom(index : Int) : Atom
      @atom_map[index]
    end

    def atom?(index : Int) : Atom?
      @atom_map[index]?
    end

    def bond(name : String, other : String, order : BondOrder = :single) : Bond
      atom!(name).bonds.add atom!(other), order
    end

    def bond(i : Int, j : Int, order : BondOrder = :single, aromatic : Bool = false) : Bond
      bond = atom(i).bonds.add atom(j), order
      aromatic_bonds << bond if aromatic
      bond
    end

    def bonds(bond_table : Hash(Tuple(Int32, Int32), BondOrder)) : Nil
      atom_table = {} of Int32 => Atom
      atom_numbers = Set(Int32).new bond_table.size * 2
      bond_table.each_key { |(i, j)| atom_numbers << i << j }
      @structure.atoms.each do |atom|
        atom_table[atom.number] = atom if atom.number.in?(atom_numbers)
      end
      bond_table.each do |(i, j), order|
        if (lhs = atom_table[i]?) && (rhs = atom_table[j]?)
          lhs.bonds.add rhs, order
        end
      end
    end

    def build : Structure
      kekulize
      @structure.apply_templates if @use_templates

      if @guess_bonds
        # skip bond order and formal charge assignment if a protein chain
        # has missing hydrogens (very common in PDB)
        include_h = !@structure.residues.any? do |residue|
          residue.protein? && !residue.atoms.any?(&.hydrogen?)
        end
        @structure.guess_bonds perceive_order: include_h
        @structure.guess_formal_charges if include_h
      end

      @structure.guess_names if @guess_names
      if @guess_bonds || @guess_names || @use_templates
        @structure.guess_unknown_residue_types
      end

      @structure
    end

    def chain : Chain
      @chain || next_chain
    end

    def chain(& : self ->) : Nil
      next_chain
      with self yield self
    end

    def chain(id : Char) : Chain
      @chain = @structure[id]? || Chain.new(@structure, id)
    end

    def chain(id : Char, & : self ->) : Nil
      chain id
      with self yield self
    end

    def current_chain : Chain?
      @chain
    end

    def current_residue : Residue?
      @residue
    end

    def expt(expt : Structure::Experiment?)
      @structure.experiment = expt
    end

    def cell : Spatial::Parallelepiped?
      @structure.cell?
    end

    def cell! : Spatial::Parallelepiped
      @structure.cell? || raise Spatial::NotPeriodicError.new
    end

    def cell(cell : Spatial::Parallelepiped?)
      @structure.cell = cell
    end

    def cell(a : Spatial::Vec3, b : Spatial::Vec3, c : Spatial::Vec3) : Spatial::Parallelepiped
      @structure.cell = Spatial::Parallelepiped.new a, b, c
    end

    def cell(a : Float64, b : Float64, c : Float64) : Spatial::Parallelepiped
      @structure.cell = Spatial::Parallelepiped.new({a, b, c})
    end

    def residue : Residue
      @residue || next_residue
    end

    def residue(name : String) : Residue
      @residue = next_residue name
    end

    def residue(name : String, & : self ->) : Nil
      residue name
      with self yield self
    end

    def residue(name : String, number : Int32, inscode : Char? = nil) : Residue
      @element_counter.clear if @residue
      if residue = chain[number, inscode]?
        @residue = residue
      else
        @residue = Residue.new(chain, number, inscode, name)
      end
    end

    def residue(name : String, number : Int32, inscode : Char? = nil, & : self ->) : Nil
      residue name, number, inscode
      with self yield self
    end

    def secondary_structure(i : Tuple(Char, Int32, Char?),
                            j : Tuple(Char, Int32, Char?),
                            type : Protein::SecondaryStructure) : Nil
      return unless (ri = @structure.dig?(*i)) && (rj = @structure.dig?(*j))
      secondary_structure ri, rj, type
    end

    def secondary_structure(ri : Residue, rj : Residue, type : Protein::SecondaryStructure)
      @structure.residues.each do |residue|
        if ri <= residue <= rj
          residue.sec = type
        end
      end
    end

    def title(title : String)
      @structure.title = title
    end

    private def aromatic_bonds : Array(Bond)
      @aromatic_bonds ||= Array(Bond).new
    end

    private def atom!(name : String) : Atom
      if residue = @residue
        residue.atoms.each do |atom|
          return atom if atom.name == name
        end
      end
      raise "Unknown atom #{name.inspect}"
    end

    private def next_chain : Chain
      next_id = case id = @chain.try(&.id) || 'A'.pred
                when 'A'..'Y', 'a'..'y', '0'..'8', 'A'.pred
                  id.succ
                when 'Z'
                  'a'
                when 'z'
                  '0'
                else
                  raise ArgumentError.new("Non-alphanumeric chain id")
                end
      chain next_id
    end

    private def next_residue(name : String = "UNK") : Residue
      residue name, (chain.residues.max_of?(&.number) || 0) + 1
    end

    # Kekulizes bonds marked as aromatic. Raises an exception when bonds
    # could not be kekulized.
    #
    # Kekulization is the process of assigning double bonds to fill the
    # Lewis structure of the aromatic atoms. Different bond orderings
    # may produce distinct but valid Kekule forms. This procedure
    # requires that all atoms have explicit hydrogens such that unfilled
    # valence is due to missing double bonds only, otherwise it will
    # produce incorrect chemical structures or even fail.
    #
    # This method first groups aromatic bonds by their connectivity.
    # Then, each bond subset (ring) is kekulized independently.
    # Alternating double bonds starting from a root bond are assigned
    # based on the connectivity tree, which is traversed using the
    # iterative breadth-first search (BFS) algorithm. Different root
    # bonds are tested until a valid Kekule form is found. Otherwise, an
    # exception is raised.
    private def kekulize : Nil
      return unless bonds = @aromatic_bonds

      grouped_bonds = [] of Array(Bond)
      until bonds.empty?
        group = [bonds.pop]
        until (bonded = bonds.select { |bond| group.any?(&.bonded?(bond)) }).empty?
          group.concat bonded
          bonds.reject! &.in?(bonded)
        end
        grouped_bonds << group
      end

      grouped_bonds.each do |bonds|
        ctab = Hash(Bond, Array(Bond)).new { |hash, key| hash[key] = [] of Bond }
        bonds.each_with_index do |bond, i|
          bonds.each(within: (i + 1)..) do |other|
            next unless other.bonded?(bond)
            ctab[bond] << other
            ctab[other] << bond
          end
        end

        changeable = bonds.select(&.atoms.any?(&.missing_valence.>(0))).to_set
        kekulized = false
        subbonds = [] of Bond
        visited = Set(Bond).new bonds.size
        bonds.size.times do |i|
          next unless bonds[i].in?(changeable)

          subbonds << bonds[i]
          until subbonds.empty?
            bond = subbonds.pop
            next if bond.in?(visited)
            bond.order = :double if bond.in?(changeable) && ctab[bond].all?(&.single?)
            visited << bond
            ctab[bond].each do |other|
              subbonds << other unless other.in?(visited)
            end
          end

          if bonds.all? &.atoms.all? { |atom| atom.target_valence == atom.valence }
            kekulized = true
            break
          end

          bonds.each &.order=(:single)
          subbonds.clear
          visited.clear
        end

        raise "Could not kekulize aromatic ring" unless kekulized
      end
    end
  end
end
