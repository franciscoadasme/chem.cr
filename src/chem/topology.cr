class Chem::Topology
  include AtomCollection
  include ChainCollection
  include ResidueCollection

  @chain_table = {} of Char => Chain
  @chains = [] of Chain

  # TODO: This hack is only needed to give access atom, residue, etc. to
  # the encompasing structure that currently holds the cell and
  # coordinates.
  @structure = uninitialized Structure
  property structure : Structure

  def [](chain_id : Char) : Chain
    self[chain_id]? || raise KeyError.new
  end

  def []?(chain_id : Char) : Chain?
    @chain_table[chain_id]?
  end

  protected def <<(chain : Chain) : self
    @chains << chain
    @chain_table[chain.id] = chain
    self
  end

  def clear : self
    @chain_table.clear
    @chains.clear
    self
  end

  def clone : self
    top = Topology.new
    # TODO: drop copy_to and implement the nested loops here
    @chains.each &.copy_to(top)
    bonds.each do |bond|
      a, b = bond
      a = top.dig a.chain.id, a.residue.number, a.residue.insertion_code, a.name
      b = top.dig b.chain.id, b.residue.number, b.residue.insertion_code, b.name
      a.bonds.add b, order: bond.order
    end
    top
  end

  def delete(ch : Chain) : Chain?
    ch = @chains.delete ch
    @chain_table.delete(ch.id) if ch && @chain_table[ch.id]?.same?(ch)
    ch
  end

  def dig(id : Char) : Chain
    self[id]
  end

  def dig(id : Char, *subindexes)
    self[id].dig *subindexes
  end

  def dig?(id : Char) : Chain?
    self[id]?
  end

  def dig?(id : Char, *subindexes)
    if chain = self[id]?
      chain.dig? *subindexes
    end
  end

  def each_atom : Iterator(Atom)
    iterators = [] of Iterator(Atom)
    @chains.each do |chain|
      chain.each_residue do |residue|
        iterators << residue.each_atom
      end
    end
    Iterator.chain iterators
  end

  def each_atom(&block : Atom ->)
    @chains.each do |chain|
      chain.each_atom do |atom|
        yield atom
      end
    end
  end

  def each_chain : Iterator(Chain)
    @chains.each
  end

  def each_chain(&block : Chain ->)
    @chains.each do |chain|
      yield chain
    end
  end

  def each_residue : Iterator(Residue)
    Iterator.chain @chains.each.map(&.each_residue).to_a
  end

  def each_residue(&block : Residue ->)
    @chains.each do |chain|
      chain.each_residue do |residue|
        yield residue
      end
    end
  end

  def n_atoms : Int32
    @chains.sum &.n_atoms
  end

  def n_chains : Int32
    @chains.size
  end

  def n_residues : Int32
    @chains.sum &.n_residues
  end

  # Renumber residues per chain based on the order by the output value
  # of the block.
  #
  # NOTE: This won't change the order of the existing chains.
  def renumber_residues_by(& : Residue -> _) : Nil
    @chains.each do |chain|
      chain.renumber_residues_by do |residue|
        yield residue
      end
    end
  end

  # Renumber chain and residues based on bond information.
  #
  # Residue fragments are assigned to unique chains unless
  # *split_chains* is `false`, which keeps existing chains intact.
  # Residue ordering is computed based on the link bond if available.
  #
  # NOTE: existing chains are reused to re-arrang the residues among
  # them, so avoid caching them before calling this.
  def renumber_residues_by_connectivity(split_chains : Bool = true) : Nil
    if split_chains
      id = 'A'.pred
      residues.residue_fragments.each do |residues|
        chain = dig?(id = id.succ) || Chain.new id, self
        chain.clear
        residues.each &.chain=(chain)
        chain.renumber_residues_by_connectivity
      end
    else
      @chains.each &.renumber_residues_by_connectivity
    end
  end

  protected def reset_cache : Nil
    @chain_table.clear
    @chains.sort_by! &.id
    @chains.each do |chain|
      @chain_table[chain.id] = chain
    end
  end
end

require "./topology/*"
