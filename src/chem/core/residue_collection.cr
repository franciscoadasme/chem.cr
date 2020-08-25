module Chem
  module ResidueCollection
    abstract def each_residue : Iterator(Residue)
    abstract def each_residue(&block : Residue ->)
    abstract def n_residues : Int32

    # Returns an iterator over secondary structure elements (SSEs).
    #
    # SSEs are defined as segments of consecutive, bonded residues that
    # have the same secondary structure. If `strict` is `false`,
    # residues are grouped by their secondary structure type. If
    # `handedness` is `false`, handedness is not taken into account when
    # `strict` is `false`. See `Protein::SecondaryStructure#equals?`.
    #
    # Let's say a `structure` has 25 residues with two beta strands
    # spanning residues 3-12 and 18-23, then:
    #
    # ```
    # iter = structure.each_secondary_structure
    # iter.next.map &.number # => [1, 2]
    # iter.next.map &.number # => [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    # iter.next.map &.number # => [13, 14, 15, 16, 17]
    # iter.next.map &.number # => [18, 19, 20, 21, 22, 23]
    # iter.next.map &.number # => [24, 25]
    # iter.next              # => Iterator::Stop::INSTANCE
    # ```
    #
    # Note that non-protein residues are skipped over.
    #
    # By default, a new array is created and yielded for each slice when
    # invoking `next`.
    # * If *reuse* is `false`, a new array is created for each chunk.
    # * If *reuse* is `true`, an array is created once and reused.
    # * If *reuse* is an `Array`, it will be reused instead.
    #
    # The latter can be used to prevent many memory allocations when
    # each slice of interest is to be used in a read-only fashion.
    def each_secondary_structure(
      reuse : Bool | Array(Residue) = false,
      strict : Bool = true,
      handedness : Bool = true
    ) : Iterator(ResidueView)
      each_residue
        .select(&.protein?)
        .chunk_while(reuse) do |i, j|
          i.sec.equals?(j.sec, strict, handedness) && i.bonded?(j)
        end
        .map { |residues| ResidueView.new residues }
    end

    # Iterates over secondary structure elements (SSEs), yielding both
    # the residues and secondary structure.
    #
    # SSEs are defined as segments of consecutive, bonded residues that
    # have the same secondary structure. If `strict` is `false`,
    # residues are grouped by their secondary structure type. If
    # `handedness` is `false`, handedness is not taken into account when
    # `strict` is `false`. See `Protein::SecondaryStructure#equals?`.
    #
    # Let's say a `structure` has 25 residues with two beta strands
    # spanning residues 3-12 and 18-23, then:
    #
    # ```
    # structure.each_secondary_structure do |sec, ary|
    #   puts "#{sec.to_s} at #{ary[0].number}..#{ary[-1].number}"
    # end
    # ```
    #
    # Prints:
    #
    # ```text
    # None at 1..2
    # BetaStrand at 3..12
    # None at 13..17
    # BetaStrand at 18..23
    # None at 24..25
    # ```
    #
    # Note that non-protein residues are skipped over.
    #
    # By default, a new array is created and yielded for each slice when
    # invoking `next`.
    # * If *reuse* is `false`, a new array is created for each chunk.
    # * If *reuse* is `true`, an array is created once and reused.
    # * If *reuse* is an `Array`, it will be reused instead.
    #
    # The latter can be used to prevent many memory allocations when
    # each slice of interest is to be used in a read-only fashion.
    def each_secondary_structure(
      reuse : Bool | Array(Residue) = false,
      strict : Bool = true,
      handedness : Bool = true,
      & : ResidueView, Protein::SecondaryStructure ->
    ) : Nil
      accum = reuse.is_a?(Array) ? reuse : [] of Residue
      each_residue do |j|
        next unless j.protein?
        if (i = accum.last?) &&
           (!i.sec.equals?(j.sec, strict, handedness) || !i.bonded?(j))
          yield ResidueView.new(accum), accum[0].sec
          reuse ? accum.clear : (accum = [] of Residue)
        end
        accum << j
      end
      yield ResidueView.new(accum), accum[0].sec unless accum.empty?
    end

    def link_bond : Topology::BondType?
      each_residue.compact_map(&.type.try(&.link_bond)).first?
    end

    def renumber_by_connectivity : Nil
      each_residue.map(&.chain).uniq.each do |chain|
        next unless chain.n_residues > 1
        next unless bond_t = chain.link_bond

        res_map = chain.each_residue.to_h do |residue|
          {guess_previous_residue(residue, bond_t), residue}
        end
        res_map.compare_by_identity
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

    # Sets secondary structure of every residue to none.
    def reset_secondary_structure : self
      each_residue &.sec=(:none)
      self
    end

    def residues : ResidueView
      residues = Array(Residue).new n_residues
      each_residue { |residue| residues << residue }
      ResidueView.new residues
    end

    def sec=(sec : Protein::SecondaryStructure) : Protein::SecondaryStructure
      each_residue &.sec=(sec)
      sec
    end

    def sec=(seclist : Array(Protein::SecondaryStructure)) : Array(Protein::SecondaryStructure)
      raise ArgumentError.new "Mismatch secondary structure list" if seclist.size != n_residues
      each_residue.zip(seclist) { |res, sec| res.sec = sec }
      seclist
    end

    def secondary_structures(strict : Bool = true, handedness : Bool = true) : Array(ResidueView)
      elements = [] of ResidueView
      each_secondary_structure(strict: strict, handedness: handedness) do |ele|
        elements << ele
      end
      elements
    end

    private def guess_previous_residue(residue : Residue, link_bond : Topology::BondType) : Residue?
      prev_res = nil
      if atom = residue[link_bond[1]]?
        prev_res = atom.each_bonded_atom.find(&.name.==(link_bond[0].name)).try &.residue
        prev_res ||= atom.each_bonded_atom.find do |atom|
          atom.element == link_bond[0].element && atom.residue != residue
        end.try &.residue
      else
        residue.each_atom do |atom|
          next unless atom.element == link_bond[1].element
          prev_res = atom.each_bonded_atom.find do |atom|
            atom.element == link_bond[0].element && atom.residue != residue
          end.try &.residue
          break if prev_res
        end
      end
      prev_res
    end
  end
end
