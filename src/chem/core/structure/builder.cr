module Chem
  class Structure::Builder
    @aromatic_bonds : Array(Bond)?
    @atom_serial : Int32 = 0
    @atoms : Indexable(Atom)?
    @chain : Chain?
    @guess_topology = false
    @residue : Residue?
    @structure : Structure

    def initialize(*args, @guess_topology : Bool = false, **options)
      @structure = Structure.new **options
    end

    # TODO: #build is often not called when using this, which can lead
    # to incorrect structures
    def initialize(structure : Structure)
      @structure = structure
      structure.each_chain { |chain| @chain = chain }
      @chain.try &.each_residue { |residue| @residue = residue }
      @atom_serial = structure.each_atom.max_of?(&.serial) || 0
    end

    def atom(coords : Spatial::Vec3, **options) : Atom
      atom :C, coords, **options
    end

    def atom(element : Element | Symbol, coords : Spatial::Vec3, **options) : Atom
      element = PeriodicTable[element.to_s.capitalize] if element.is_a?(Symbol)
      id = residue.each_atom.count(&.element.==(element)) + 1
      atom "#{element.symbol}#{id}", coords, **options.merge(element: element)
    end

    def atom(name : String, coords : Spatial::Vec3, **options) : Atom
      Atom.new name, (@atom_serial += 1), coords, residue, **options
    end

    def atom(name : String, serial : Int32, coords : Spatial::Vec3, **options) : Atom
      @atom_serial = serial
      Atom.new name, @atom_serial, coords, residue, **options
    end

    def bond(name : String, other : String, order : Int = 1) : Bond
      atom!(name).bonds.add atom!(other), order
    end

    def bond(i : Int, j : Int, order : Int = 1, aromatic : Bool = false) : Bond
      bond = atoms[i].bonds.add atoms[j], order
      aromatic_bonds << bond if aromatic
      bond
    end

    def bonds(bond_table : Hash(Tuple(Int32, Int32), Int32)) : Nil
      atom_table = {} of Int32 => Atom
      atom_serials = Set(Int32).new bond_table.size * 2
      bond_table.each_key { |(i, j)| atom_serials << i << j }
      @structure.each_atom do |atom|
        atom_table[atom.serial] = atom if atom.serial.in?(atom_serials)
      end
      bond_table.each do |(i, j), order|
        if (lhs = atom_table[i]?) && (rhs = atom_table[j]?)
          lhs.bonds.add rhs, order
        end
      end
    end

    def build : Structure
      kekulize
      @structure.topology.apply_templates

      # skip bond order and formal charge assignment if a protein chain
      # has missing hydrogens (very common in PDB)
      include_h = !@structure.each_residue.any? { |r| r.protein? && !r.has_hydrogens? }
      @structure.topology.guess_bonds perceive_order: include_h
      @structure.topology.guess_formal_charges if include_h

      @structure.topology.guess_unknown_residue_types
      @structure.topology.guess_names if @guess_topology
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
      @chain = @structure[id]? || Chain.new(id, @structure.topology)
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
      @structure.cell
    end

    def cell! : Spatial::Parallelepiped
      @structure.cell || raise Spatial::NotPeriodicError.new
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
      @residue = chain[number, inscode]? || Residue.new(name, number, inscode, chain)
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
      @structure.each_residue do |residue|
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
        residue.each_atom do |atom|
          return atom if atom.name == name
        end
      end
      raise "Unknown atom #{name.inspect}"
    end

    private def atoms : Indexable(Atom)
      @atoms ||= @structure.atoms
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
      residue name, (chain.each_residue.max_of?(&.number) || 0) + 1
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

        changeable = bonds.select { |bond| bond[0].missing_valence > 0 && bond[1].missing_valence > 0 }.to_set
        kekulized = false
        subbonds = [] of Bond
        visited = Set(Bond).new bonds.size
        bonds.size.times do |i|
          next unless bonds[i].in?(changeable)

          subbonds << bonds[i]
          until subbonds.empty?
            bond = subbonds.pop
            next if bond.in?(visited)
            bond.order = 2 if bond.in?(changeable) && ctab[bond].all?(&.single?)
            visited << bond
            ctab[bond].each do |other|
              subbonds << other unless other.in?(visited)
            end
          end

          if bonds.all? { |bond| bond[0].nominal_valence == bond[0].valence && bond[1].nominal_valence == bond[1].valence }
            kekulized = true
            break
          end

          bonds.each &.order=(1)
          subbonds.clear
          visited.clear
        end

        raise "Could not kekulize aromatic ring" unless kekulized
      end
    end
  end
end
