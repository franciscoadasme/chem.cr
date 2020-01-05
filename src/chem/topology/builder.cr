require "./templates/all"

module Chem::Topology
  class Builder
    MAX_CHAINS          =  62 # remove artificial limit
    MAX_COVALENT_RADIUS = 5.0

    @aromatic_bonds : Array(Bond)?
    @atom_serial : Int32 = 0
    @atoms : Indexable(Atom)?
    @chain : Chain?
    @covalent_dist_table : Hash(Tuple(String, String), Float64)?
    @kdtree : Spatial::KDTree?
    @residue : Residue?
    @structure : Structure

    def initialize(structure : Structure? = nil)
      if structure
        @structure = structure
        structure.each_chain { |chain| @chain = chain }
        structure.each_residue { |residue| @residue = residue }
        @atom_serial = structure.each_atom.max_of &.serial
      else
        @structure = Structure.new
      end
    end

    def self.build(structure : Structure? = nil) : Structure
      builder = new structure
      with builder yield builder
      builder.build
    end

    def atom(coords : Spatial::Vector, **options) : Atom
      atom :C, coords, **options
    end

    def atom(element : Element | Symbol, coords : Spatial::Vector, **options) : Atom
      element = PeriodicTable[element.to_s.capitalize] if element.is_a?(Symbol)
      id = residue.each_atom.count(&.element.==(element)) + 1
      atom "#{element.symbol}#{id}", coords, **options.merge(element: element)
    end

    def atom(name : String, coords : Spatial::Vector, **options) : Atom
      Atom.new name, (@atom_serial += 1), coords, residue, **options
    end

    def atom(name : String, serial : Int32, coords : Spatial::Vector, **options) : Atom
      @atom_serial = serial
      Atom.new name, @atom_serial, coords, residue, **options
    end

    def assign_topology_from_templates
      @structure.each_residue do |residue|
        next unless res_t = Templates[residue.name]?
        assign_template residue, res_t
      end
      guess_unknown_residue_types
    end

    def bond(name : String, other : String, order : Int = 1) : Bond
      atom!(name).bonds.add atom!(other), order
    end

    def bond(i : Int, j : Int, order : Int = 1, aromatic : Bool = false) : Bond
      bond = atoms[i].bonds.add atoms[j], order
      aromatic_bonds << bond if aromatic
      bond
    end

    def build : Structure
      transform_aromatic_bonds
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
      @chain = @structure[id]? || Chain.new(id, @structure)
    end

    def chain(id : Char, & : self ->) : Nil
      chain id
      with self yield self
    end

    def expt(expt : Structure::Experiment?)
      @structure.experiment = expt
    end

    def guess_bonds_from_geometry : Nil
      guess_connectivity_from_geometry @structure
      guess_bond_orders @structure
      guess_formal_charges @structure
    end

    # Guesses topology (chain, residue and atom names) from existing bonds.
    #
    # Atoms are split in fragments, where each fragment is mapped to a list of residues.
    # Then, fragments are divided into polymers (e.g., peptide) and non-polymer
    # fragments (e.g., water), where residues assigned to the latter are grouped
    # together by their kind (i.e., protein, ion, solvent, etc.). Finally, polymer
    # fragments and residues grouped by kind are assigned to their own unique chain as
    # long as there are less residue groups than the chain limit (62), otherwise all
    # residues are assigned to the same chain.
    def guess_topology_from_connectivity : Nil
      raise Error.new "Structure has no bonds" if @structure.bonds.empty?
      return unless old_chain = @structure.delete(@structure.chains.first)

      @chain = nil
      @residue = nil

      detector = Templates::Detector.new Templates.all
      fragments = old_chain.fragments.map do |atoms|
        guess_residues detector, old_chain, atoms.to_a
      end

      polymer_chains, other = fragments.partition { |frag| frag.size > 1 }
      other = other.flatten.sort_by!(&.kind.to_i).group_by(&.kind).values
      if polymer_chains.size + other.size <= MAX_CHAINS
        fragments = polymer_chains + other
      else
        fragments = [fragments.flatten]
      end

      fragments.each do |residues|
        chain = next_chain
        residues.each do |residue|
          residue.number = chain.n_residues + 1
          residue.chain = chain
        end
      end
    end

    def lattice : Lattice?
      @structure.lattice
    end

    def lattice! : Lattice
      @structure.lattice || raise Spatial::NotPeriodicError.new
    end

    def lattice(lattice : Lattice?)
      @structure.lattice = lattice
    end

    def lattice(a : Spatial::Vector, b : Spatial::Vector, c : Spatial::Vector) : Lattice
      @structure.lattice = Lattice.new a, b, c
    end

    def lattice(a : Float64, b : Float64, c : Float64) : Lattice
      @structure.lattice = Lattice.new Spatial::Size[a, b, c]
    end

    def renumber_by_connectivity : Nil
      raise Error.new "Structure has no bonds" if @structure.bonds.empty?
      @structure.each_chain do |chain|
        next unless chain.n_residues > 1
        next unless link_bond = chain.each_residue.compact_map do |residue|
                      Templates[residue.name]?.try &.link_bond
                    end.first?

        res_map = chain.each_residue.to_h do |residue|
          {guess_previous_residue(residue, link_bond), residue}
        end
        res_map[nil] = chain.residues.first unless res_map.has_key? nil

        prev_res = nil
        chain.n_residues.times do |i|
          next_res = res_map[prev_res]
          next_res.number = i + 1
          prev_res = next_res
        end
        chain.reset_cache
      end
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
      @residue = chain[number, inscode]? || begin
        residue = Residue.new(name, number, inscode, chain)
        if res_t = Topology::Templates[name]?
          residue.kind = Residue::Kind.from_value res_t.kind.to_i
        end
        residue
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
      loop do
        ri.secondary_structure = type
        break unless ri != rj && (ri = ri.next)
      end
    end

    def seq(seq : Protein::Sequence?)
      @structure.sequence = seq
    end

    def title(title : String)
      @structure.title = title
    end

    private def assign_bond_from_template(residue : Residue,
                                          other : Residue,
                                          bond_t : Templates::BondType) : Nil
      if (i = residue[bond_t.first]?) && (j = other[bond_t.second]?) && !i.bonded?(j)
        d = Spatial.squared_distance i, j
        i.bonds.add j, bond_t.order if d <= covalent_cutoff(i, j)
      end
    end

    private def assign_template(residue : Residue, res_t : Templates::ResidueType) : Nil
      residue.kind = res_t.kind
      res_t.bonds.each { |bond_t| assign_bond_from_template residue, residue, bond_t }
      if bond_t = res_t.link_bond
        if prev_res = residue.previous
          assign_bond_from_template prev_res, residue, bond_t
        end
        if next_res = residue.next
          assign_bond_from_template residue, next_res, bond_t
        end
      end

      res_t.each_atom_type do |atom_type|
        next unless atom = residue[atom_type.name]?
        atom.formal_charge = atom_type.formal_charge
      end
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

    private def covalent_cutoff(atom : Atom, other : Atom) : Float64
      covalent_dist_table[{atom.element.symbol, other.element.symbol}] ||= \
         (atom.covalent_radius + other.covalent_radius + 0.3) ** 2
    end

    private def covalent_dist_table : Hash(Tuple(String, String), Float64)
      @covalent_dist_table ||= {} of Tuple(String, String) => Float64
    end

    private def guess_bond_orders(atoms : AtomCollection) : Nil
      atoms.each_atom do |atom|
        next if atom.element.ionic?
        missing_bonds = missing_bonds atom
        while missing_bonds > 0
          others = atom.bonded_atoms.select { |other| missing_bonds(other) > 0 }
          break if others.empty?
          others.each(within: ...missing_bonds) do |other|
            atom.bonds[other].order += 1
            missing_bonds -= 1
          end
        end
      end
    end

    private def guess_connectivity_from_geometry(atoms : AtomCollection) : Nil
      atoms.each_atom do |a|
        next if a.element.ionic?
        kdtree.each_neighbor a, within: MAX_COVALENT_RADIUS do |b, sqr_d|
          next if b.element.ionic? || a.bonded?(b) || sqr_d > covalent_cutoff(a, b)
          next unless b.valency < b.element.max_valency
          if a.element.hydrogen? && a.bonds.size == 1
            next unless sqr_d < a.bonds[0].squared_distance
            a.bonds.delete a.bonds[0]
          end
          a.bonds.add b
        end
      end
    end

    private def guess_formal_charges(atoms : AtomCollection) : Nil
      atoms.each_atom do |atom|
        atom.formal_charge = if atom.element.ionic?
                               atom.element.max_valency
                             else
                               -missing_bonds(atom)
                             end
      end
    end

    private def guess_nominal_valency_from_connectivity(atom : Atom) : Int32
      atom.element.valencies.find(&.>=(atom.valency)) || atom.element.max_valency
    end

    private def guess_previous_residue(residue : Residue,
                                       link_bond : Templates::BondType) : Residue?
      prev_res = nil
      if atom = residue[link_bond.second]?
        prev_res = atom.bonded_atoms.find(&.name.==(link_bond.first)).try &.residue
        prev_res ||= atom.bonded_atoms.find do |atom|
          element = PeriodicTable[atom_name: link_bond.first]
          atom.element == element && atom.residue != residue
        end.try &.residue
      else
        elements = {PeriodicTable[atom_name: link_bond.first],
                    PeriodicTable[atom_name: link_bond.second]}
        residue.each_atom do |atom|
          next unless atom.element == elements[1]
          prev_res = atom.bonded_atoms.find do |atom|
            atom.element == elements[0] && atom.residue != residue
          end.try &.residue
          break if prev_res
        end
      end
      prev_res
    end

    private def guess_residues(detector : Templates::Detector,
                               chain : Chain,
                               atoms : Array(Atom)) : Array(Residue)
      residues = [] of Residue
      detector.each_match(atoms.dup) do |res_t, atom_map|
        names = res_t.atom_names

        residues << (residue = Residue.new res_t.name, residues.size + 1, chain)
        residue.kind = Residue::Kind.from_value res_t.kind.to_i
        atom_map.to_a.sort_by! { |_, k| names.index(k) || 99 }.each do |atom, name|
          atom.name = name
          atom.residue = residue
          atoms.delete atom
        end
      end

      unless atoms.empty?
        residues << (residue = Residue.new "UNK", chain.residues.size, chain)
        atoms.each &.residue=(residue)
      end

      residues
    end

    private def guess_unknown_residue_types : Nil
      @structure.each_residue do |res|
        next unless res.kind.other?
        next unless (other = res.previous || res.next)
        next unless bond_t = Templates[other.name].link_bond

        if (prev_res = res.previous) && (next_res = res.next)
          next unless prev_res.kind == next_res.kind &&
                      prev_res.bonded?(res, bond_t) &&
                      res.bonded?(next_res, bond_t)
        elsif prev_res = res.previous
          next unless prev_res.bonded?(res, bond_t)
        elsif next_res = res.next
          next unless res.bonded?(next_res, bond_t)
        end

        res.kind = other.kind
      end
    end

    private def kdtree : Spatial::KDTree
      @kdtree ||= Spatial::KDTree.new @structure,
        periodic: @structure.periodic?,
        radius: MAX_COVALENT_RADIUS
    end

    private def missing_bonds(atom : Atom) : Int32
      guess_nominal_valency_from_connectivity(atom) - atom.valency
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

    private def transform_aromatic_bonds : Nil
      return unless bonds = @aromatic_bonds
      bonds.sort_by! { |bond| Math.min bond[0].serial, bond[1].serial }
      until bonds.empty?
        bond = bonds.shift
        if other = bonds.find { |b| b.includes?(bond[0]) || b.includes?(bond[1]) }
          bonds.delete other
          (bond[1] != other[0] ? bond : other).order = 2
        end
      end
    end
  end
end
