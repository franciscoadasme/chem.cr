module Chem::Protein
  # Pure Crystal implementation of the Dictionary of Protein Secondary Structure (DSSP)
  # algorithm (Kabsch, W.; Sander, C. *Biopolymers* **1983**, *22* (12), 2577–2637.
  # [doi:10.1002/bip.360221211][1]).
  #
  # This implementation is based on the `mkdssp` program, version 3.0.5, written by
  # Maarten L. Hekkelman, currently maintained by Coos Baakman, Jon Black, and Wouter
  # Touw, and distributed under the Boost Software license at the
  # [github.com/cmbi/xssp][2] repository.
  #
  # Consider that, according to the algorithm, residues that do not contain backbone
  # atoms, namely, "N", "CA", "C", and "O", are ignored. Therefore, non-standard amino
  # acids are considered during the assignment as long as they contain such atoms.
  # Otherwise, they will be considered as protein gaps, which may alter the secondary
  # structure of surrounding residues.
  #
  # Note that some differences may be expected with the output of `mkdssp` due to:
  #
  # - `mkdssp` does not handle well alternate conformations in PDB files, sometimes
  #   discarding entire aminoacids.
  # - `mkdssp` detects chain breaks by checking non-consecutive numbers of neighboring
  #   residues. This may fail when residues *i* and *i + 1* are not actually bonded, or
  #   when residue numbers are not consecutive. This implementation instead checks that
  #   the C(*i*)–N(*i*+1) bond length is within covalent distance.
  #
  # FIXME: it does not work correctly for periodic structures that have
  # bonds between atoms at opposite ends.
  #
  # NOTE: This implementation of DSSP is currently 50% slower than pure C++ solutions, so
  # keep this in mind when assigning the secondary structure of many structures.
  #
  # [1]: http://dx.doi.org/10.1002/bip.360221211
  # [2]: http://github.com/cmbi/xssp
  class DSSP < SecondaryStructureCalculator
    MAX_CN_BOND_SQUARED_DIST = (0.76 + 0.71 + 0.3)**2 # DSSP paper suggest 2.5 A
    MIN_CA_SQUARED_DIST      =      81
    HBOND_COUPLING_FACTOR    = -27.888
    HBOND_ENERGY_CUTOFF      =    -0.5
    HBOND_MIN_ENERGY         =    -9.9

    @bridges = [] of Bridge
    @coords : Array(Coords)
    @hbonds = {} of Tuple(Int32, Int32) => Float64
    @helices = Hash(Tuple(Int32, Int32), Helix::Type).new { Helix::Type::None }

    def initialize(@structure : Structure)
      @residues = ResidueView.new structure.residues.to_a.select!(&.has_backbone?)
      @coords = @residues.map { |res| Coords.new res }
    end

    def assign : Nil
      reset_secondary_structure
      calculate_hbonds
      assign_beta_sheets if @residues.size > 4
      assign_helices
      assign_bends_and_turns
    end

    private def alpha_angle(index : Int) : Float64
      if (j = res(index)["CA"]?) &&
         (i = res(index).previous.try(&.["CA"]?)) &&
         (k = res(index).next.try(&.["CA"]?)) &&
         (l = res(index).next.try(&.next).try(&.["CA"]?))
        Spatial.dihedral i, j, k, l
      else
        360.0
      end
    end

    private def assign_3_10_helices : Nil
      1.upto(@residues.size - 4) do |i|
        next unless @helices[{i, 3}].start? && @helices[{i - 1, 3}].start?
        next if i.upto(i + 2).any? { |j| !sec(j).none? && !sec(j).helix3_10? }
        sec = if chirality(i, i + 2) >= 0
                SecondaryStructure::RightHandedHelix3_10
              else
                SecondaryStructure::LeftHandedHelix3_10
              end
        i.upto(i + 2) do |j|
          res(j).sec = sec
        end
      end
    end

    private def assign_alpha_helices : Nil
      1.upto(@residues.size - 5) do |i|
        next unless @helices[{i, 4}].start? && @helices[{i - 1, 4}].start?
        sec = if chirality(i, i + 3) >= 0
                SecondaryStructure::RightHandedHelixAlpha
              else
                SecondaryStructure::LeftHandedHelixAlpha
              end
        i.upto(i + 3) do |j|
          res(j).sec = sec
        end
      end
    end

    private def assign_bends_and_turns : Nil
      1.upto(@residues.size - 2) do |i|
        next unless sec(i).none?
        if turn? i
          res(i).sec = :turn
        elsif bend? i
          res(i).sec = :bend
        end
      end
    end

    private def assign_beta_sheets : Nil
      calculate_bridges
      @bridges.sort!
      merge_bridges
      @bridges.each do |bridge|
        ss = bridge.i.size > 1 ? SecondaryStructure::BetaStrand : SecondaryStructure::BetaBridge
        {bridge.i, bridge.j}.each do |idxs|
          idxs.first.upto(idxs.last) do |i|
            res(i).sec = ss unless res(i).sec.beta_strand?
          end
        end
      end
    end

    private def assign_helices : Nil
      calculate_helices
      assign_alpha_helices
      assign_3_10_helices
      assign_pi_helices
    end

    private def assign_pi_helices : Nil
      1.upto(@residues.size - 6) do |i|
        next unless @helices[{i, 5}].start? && @helices[{i - 1, 5}].start?
        next if i.upto(i + 4).any? do |j|
                  !sec(j).none? && !sec(j).helix_pi? && !sec(j).helix_alpha?
                end
        sec = if chirality(i, i + 4) >= 0
                SecondaryStructure::RightHandedHelixPi
              else
                SecondaryStructure::LeftHandedHelixPi
              end
        i.upto(i + 4) do |j|
          res(j).sec = sec
        end
      end
    end

    private def bend?(i : Int32) : Bool
      return false unless i > 1 && i < @residues.size - 2
      return false if gap? i - 2, i + 2
      u, v = coords(i - 2).ca - coords(i).ca, coords(i).ca - coords(i + 2).ca
      ckap = u.dot(v) / (u.size * v.size)
      kappa = Math.atan2(Math.sqrt(1 - ckap * ckap), ckap)
      kappa.degrees > 70
    end

    private def bulge?(bi : Bridge, bj : Bridge) : Bool
      return false unless bi.kind == bj.kind

      ibi = bi.i.first
      iei = bi.i.last
      jbi = bi.j.first
      jei = bi.j.last
      ibj = bj.i.first
      iej = bj.i.last
      jbj = bj.j.first
      jej = bj.j.last

      return false if gap?({ibi, ibj}.min, {iei, iej}.max)
      return false if gap?({jbi, jbj}.min, {jei, jej}.max)
      return false if (ibj >= iei && ibj - iei >= 6) || (iei >= ibj && ibi <= iej)

      if bi.parallel?
        ((jbj >= jei && jbj - jei < 6) && (ibj >= iei && ibj - iei < 3)) ||
          (jbj >= jei && jbj - jei < 3)
      else
        ((jbi >= jej && jbi - jej < 6) && (ibj >= iei && ibj - iei < 3)) ||
          (jbi >= jej && jbi - jej < 3)
      end
    end

    private def calculate_bridges : Nil
      1.upto(@residues.size - 5) do |i|
        (i + 3).upto(@residues.size - 2) do |j|
          next if (bridge_t = evaluate_bridge i, j).none?
          if bridge = find_bridge(bridge_t, i, j)
            bridge.i << i
            bridge_t.parallel? ? bridge.j.push(j) : bridge.j.unshift(j)
          else
            @bridges << Bridge.new @bridges.size, bridge_t, i, j
          end
        end
      end
    end

    private def calculate_hbonds
      (0...@residues.size).each do |i|
        (i + 1).upto(@residues.size - 1) do |j|
          ci, cj = coords(i), coords(j)
          next unless Spatial.squared_distance(ci.ca, cj.ca) < MIN_CA_SQUARED_DIST
          energy = calculate_hbond_energy donor: ci, acceptor: cj
          @hbonds[{i, j}] = energy if energy < HBOND_ENERGY_CUTOFF
          if i + 1 != j
            energy = calculate_hbond_energy donor: cj, acceptor: ci
            @hbonds[{j, i}] = energy if energy < HBOND_ENERGY_CUTOFF
          end
        end
      end
    end

    private def calculate_hbond_energy(donor : Coords, acceptor : Coords) : Float64
      rd_ho = 1 / Spatial.distance(donor.h, acceptor.o)
      rd_hc = 1 / Spatial.distance(donor.h, acceptor.c)
      rd_nc = 1 / Spatial.distance(donor.n, acceptor.c)
      rd_no = 1 / Spatial.distance(donor.n, acceptor.o)

      energy = HBOND_COUPLING_FACTOR * (rd_ho - rd_hc + rd_nc - rd_no)
      energy = (energy * 1000).round / 1000 # xssp compatibility mode
      energy < HBOND_MIN_ENERGY ? HBOND_MIN_ENERGY : energy
    end

    private def calculate_helices
      @residues.size.times.chunk(reuse: true) { |i| chain(i) }.each do |_, ary|
        (3..5).each do |stride|
          calculate_helices ary, stride
        end
      end
    end

    private def calculate_helices(idxs : Array(Int32), stride : Int32)
      0.upto(idxs.size - stride - 1) do |i|
        i = idxs.unsafe_fetch i
        next unless hbond?(i + stride, i) && !gap?(i, i + stride)

        @helices[{i + stride, stride}] = :end
        (i + 1).upto(i + stride - 1) do |j|
          @helices[{j, stride}] = :middle if @helices[{j, stride}].none?
        end

        if @helices[{i, stride}].end?
          @helices[{i, stride}] = :start_end
        else
          @helices[{i, stride}] = :start
        end
      end
    end

    private def chain(index : Int) : Char
      @residues[index]?.try(&.chain.id) || ' '
    end

    private def chirality(i : Int, j : Int) : Int32
      (i..j).sum { |k| alpha_angle(k) > 0 ? 1 : -1 }.sign
    end

    private def coords(index : Int) : Coords
      @coords.unsafe_fetch index
    end

    private def evaluate_bridge(i : Int32, j : Int32) : Bridge::Type
      a, b, c = i - 1, i, i + 1
      d, e, f = j - 1, j, j + 1

      unless gap?(a, c) || gap?(d, f)
        if (hbond?(c, e) && hbond?(e, a)) || (hbond?(f, b) && hbond?(b, d))
          Bridge::Type::Parallel
        elsif (hbond?(c, d) && hbond?(f, a)) || (hbond?(e, b) && hbond?(b, e))
          Bridge::Type::AntiParallel
        else
          Bridge::Type::None
        end
      else
        Bridge::Type::None
      end
    end

    private def find_bridge(bridge_t : Bridge::Type, i : Int32, j : Int32) : Bridge?
      @bridges.find do |bridge|
        next if bridge.kind != bridge_t || i != bridge.i.last + 1
        if bridge_t.parallel?
          bridge.j.last + 1 == j
        elsif bridge_t.anti_parallel?
          bridge.j.first - 1 == j
        end
      end
    end

    private def gap?(i : Int, j : Int) : Bool
      i.upto(j - 1).any? do |i|
        Spatial.squared_distance(coords(i).c, coords(i + 1).n) > MAX_CN_BOND_SQUARED_DIST
      end
    end

    private def hbond?(donor : Int32, acceptor : Int32) : Bool
      @hbonds.has_key?({donor, acceptor})
    end

    private def merge_bridges : Nil
      i = 0
      while i < @bridges.size
        bi = @bridges.unsafe_fetch i
        j = i
        while j < @bridges.size - 1
          j += 1
          bj = @bridges.unsafe_fetch j
          next unless bulge?(bi, bj)
          bi.merge! bj
          @bridges.delete_at j
          j -= 1
        end
        i += 1
      end
    end

    private def res(at index : Int) : Residue
      @residues.unsafe_fetch index
    end

    private def sec(at index : Int) : Protein::SecondaryStructure
      res(at: index).sec
    end

    private def turn?(i : Int) : Bool
      (3..5).any? do |stride|
        (1...stride).any? do |k|
          i >= k && @helices[{i - k, stride}].start?
        end
      end
    end

    private struct Bridge
      include Comparable(Bridge)

      enum Type
        None
        Parallel
        AntiParallel
      end

      getter i = Deque(Int32).new
      getter index : Int32
      getter j = Deque(Int32).new
      getter kind : Type

      delegate antiparallel?, parallel?, to: @kind

      def initialize(@index : Int32, @kind : Type, i : Int32, j : Int32)
        @i << i
        @j << j
      end

      def <=>(other : self) : Int32
        i.first <=> other.i.first
      end

      def merge!(other : self)
        @i.concat other.i
        if parallel?
          @j.concat other.j
        else
          other.j.reverse_each { |k| @j.unshift k }
        end
      end

      def to_s(io : IO)
        io << @index << ':' << (parallel? ? 'p' : 'a') << ":[" << @i.size << ":"
        @i.join ',', io
        io << '/' << @j.size << ":"
        @j.join ',', io
        io << ']'
      end
    end

    private struct Coords
      getter c : Spatial::Vector
      getter ca : Spatial::Vector
      getter h : Spatial::Vector
      getter n : Spatial::Vector
      getter o : Spatial::Vector

      def initialize(residue : Residue)
        @n = residue["N"]?.as(Atom).coords
        @h = Coords.guess_hydrogen residue
        @c = residue["C"]?.as(Atom).coords
        @o = residue["O"]?.as(Atom).coords
        @ca = residue["CA"]?.as(Atom).coords
      end

      def self.guess_hydrogen(residue : Residue) : Spatial::Vector
        r_n = residue["N"]?.as(Atom).coords
        return r_n if residue.name == "PRO"
        return r_n unless prev_res = residue.previous
        return r_n unless carbon = prev_res["C"]?
        return r_n unless oxygen = prev_res["O"]?
        r_n + ((carbon.coords - oxygen.coords) / Spatial.distance(carbon, oxygen))
      end
    end

    private struct Helix
      enum Type
        None
        Start
        End
        StartEnd
        Middle

        def start? : Bool
          self == Start || self == StartEnd
        end
      end
    end
  end
end
