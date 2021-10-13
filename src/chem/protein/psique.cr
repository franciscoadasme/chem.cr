module Chem::Protein
  class PSIQUE < SecondaryStructureCalculator
    CURVATURE_CUTOFF = 60

    HBOND_DISTANCE       = 1.5..2.6 # hydrogen---acceptor
    HBOND_MIN_ANGLE      = 120      # donor-hydrogen---acceptor
    MIN_RESIDUE_DISTANCE =   3

    getter? blend_elements : Bool

    @residues : ResidueView

    def initialize(structure : Structure, @blend_elements : Bool = true)
      super structure
      @residues = structure.residues.select(&.protein?)
      @raw_sec = Array(SecondaryStructure).new @residues.size, SecondaryStructure::None
      @bridged_residues = Set(Residue).new @residues.size
    end

    def assign : Nil
      reset_secondary_structure
      update_bridged_residues
      assign_secondary_structure
      extend_elements
      reassign_enclosed_elements
      normalize_regular_elements
    end

    protected class_getter basins : Array(Basin) do
      [
        Basin.new(
          sec: SecondaryStructure::RightHandedHelixPi,
          x0: 1.15.scale(0, 4),
          y0: 78.4.scale(0, 360),
          sigma_x: 0.158.scale(0, 4),
          sigma_y: 8.31.scale(0, 360),
          height: 11.08,
          theta: -20.0.radians,
          offset: -60_896.0,
        ),
        Basin.new(
          sec: SecondaryStructure::RightHandedHelixAlpha,
          x0: 1.47.scale(0, 4),
          y0: 97.1.scale(0, 360),
          sigma_x: 0.160.scale(0, 4),
          sigma_y: 12.04.scale(0, 360),
          height: 8.84,
          theta: -20.0.radians,
          offset: 2_879_597.0,
        ),
        Basin.new(
          sec: SecondaryStructure::RightHandedHelix3_10,
          x0: 1.96.scale(0, 4),
          y0: 113.2.scale(0, 360),
          sigma_x: 0.343.scale(0, 4),
          sigma_y: 21.10.scale(0, 360),
          height: 10.24,
          theta: -20.0.radians,
          offset: 1_330_117.0,
        ),
        Basin.new(
          sec: SecondaryStructure::RightHandedHelixGamma,
          x0: 2.79.scale(0, 4),
          y0: 168.2.scale(0, 360),
          sigma_x: 0.185.scale(0, 4),
          sigma_y: 36.0.scale(0, 360),
          height: 6.79,
          theta: 16.9.radians,
          offset: 96_962.0,
        ),
        Basin.new(
          sec: SecondaryStructure::Polyproline,
          x0: 3.06.scale(0, 4),
          y0: 239.6.scale(0, 360),
          sigma_x: 0.4.scale(0, 4),
          sigma_y: 18.93.scale(0, 360),
          height: 2.86,
          theta: -161.8.radians,
          offset: -2_226_279.0,
        ),
        Basin.new(
          sec: SecondaryStructure::BetaStrand,
          x0: 3.48.scale(0, 4),
          y0: 180.0.scale(0, 360),
          sigma_x: 0.264.scale(0, 4),
          sigma_y: 36.0.scale(0, 360),
          height: 5.74,
          theta: 12.6.radians,
          offset: -2_019_507.0,
        ),
        Basin.new(
          sec: SecondaryStructure::LeftHandedHelixPi,
          x0: -1.16.scale(0, 4),
          y0: 82.0.scale(0, 360),
          sigma_x: 0.158.scale(0, 4),
          sigma_y: 8.31.scale(0, 360),
          height: 11.08,
          theta: 20.0.radians,
          offset: -60_896.0,
        ),
        Basin.new(
          sec: SecondaryStructure::LeftHandedHelixAlpha,
          x0: -1.47.scale(0, 4),
          y0: 96.5.scale(0, 360),
          sigma_x: 0.160.scale(0, 4),
          sigma_y: 12.04.scale(0, 360),
          height: 8.84,
          theta: 20.0.radians,
          offset: 2_879_597.0,
        ),
        Basin.new(
          sec: SecondaryStructure::LeftHandedHelix3_10,
          x0: -1.93.scale(0, 4),
          y0: 115.5.scale(0, 360),
          sigma_x: 0.343.scale(0, 4),
          sigma_y: 21.10.scale(0, 360),
          height: 10.24,
          theta: 20.0.radians,
          offset: 1_330_117.0,
        ),
        Basin.new(
          sec: SecondaryStructure::LeftHandedHelixGamma,
          x0: -2.81.scale(0, 4),
          y0: 170.0.scale(0, 360),
          sigma_x: 0.185.scale(0, 4),
          sigma_y: 36.0.scale(0, 360),
          height: 6.79,
          theta: -16.9.radians,
          offset: 96_962.0,
        ),
        Basin.new(
          sec: SecondaryStructure::Polyproline,
          x0: -3.06.scale(0, 4),
          y0: 239.6.scale(0, 360),
          sigma_x: 0.4.scale(0, 4),
          sigma_y: 18.93.scale(0, 360),
          height: 2.86,
          theta: 161.8.radians,
          offset: -2_226_279.0,
        ),
        Basin.new(
          sec: SecondaryStructure::BetaStrand,
          x0: -3.48.scale(0, 4),
          y0: 180.0.scale(0, 360),
          sigma_x: 0.264.scale(0, 4),
          sigma_y: 36.0.scale(0, 360),
          height: 5.74,
          theta: -12.6.radians,
          offset: -2_019_507.0,
        ),
      ]
    end

    protected class_getter pes : Hash(Int32, EnergySurface) do
      {
         1 => EnergySurface.new(basins[..5]),
        -1 => EnergySurface.new(basins[6..]),
      }
    end

    private def assign_secondary_structure
      curvature = Array(Float64).new @residues.size, Float64::MAX
      hlxparams = @residues.map(&.hlxparams)
      @residues.each_with_index do |res, i|
        next unless h2 = hlxparams[i]

        h1 = hlxparams[i - 1] if i > 0 && res.bonded?(@residues[i - 1])
        h3 = hlxparams[i + 1] if i < @residues.size - 1 && res.bonded?(@residues[i + 1])
        if h1 && h3
          dprev = Spatial.distance h1.to_q, h2.to_q
          dnext = Spatial.distance h2.to_q, h3.to_q
          curvature[i] = ((dprev + dnext) / 2).degrees
        end

        raw_pitch = h2.pitch.scale(0, 4)
        raw_twist = h2.twist.scale(0, 360)
        pes = PSIQUE.pes[raw_pitch >= 0 ? 1 : -1]
        pitch, twist = pes.walk raw_pitch, raw_twist
        basin_ok = false
        if basin = pes.basin(pitch, twist)
          case basin.sec
          when .beta_strand?
            # ensure that the residue forms or is between h-bond bridges
            next unless in_bridge?(res)
          when .polyproline?, .helix_gamma?
            # check for beta_strand if the residue forms or is between h-bond bridges
            if in_bridge?(res) && pes.basin(:beta_strand).includes?(raw_pitch, raw_twist)
              basin = pes.basin :beta_strand
              basin_ok = true
            end
          end

          @raw_sec[i] = basin.sec
          if (basin_ok || basin.includes?(pitch, twist)) &&
             curvature[i] <= CURVATURE_CUTOFF
            res.sec = basin.sec
          end
        end
      end
    end

    private def in_bridge?(residue : Residue) : Bool
      residue.in?(@bridged_residues) ||
        (residue.pred.in?(@bridged_residues) &&
          residue.succ.in?(@bridged_residues))
    end

    private def extend_elements
      offset = 0
      @residues.each_secondary_structure(reuse: true) do |ele, sec|
        if sec.regular?
          {-1, 1}.each do |sense|
            i = offset + (sense > 0 ? ele.size : -1)
            while 0 <= i < @residues.size && @raw_sec[i] == sec
              @residues[i].sec = sec
              i += sense
            end
          end
        end
        offset += ele.size
      end
    end

    private def guess_hydrogen(residue : Residue) : Spatial::Vec3
      n = residue.dig("N").coords
      if (pred = residue.pred) && (c = pred.dig?("C")) && (o = pred.dig?("O"))
        n + (c.coords - o.coords).normalize
      else
        n
      end
    end

    private def normalize_regular_elements : Nil
      @residues.each_secondary_structure(reuse: true, strict: false) do |ele, sec|
        if sec.type.regular?
          if blend_elements? && ele.any?(&.sec.!=(sec))
            SecondaryStructureBlender.new(ele).blend
          end
          min_size = ele.all?(&.sec.==(sec)) ? sec.min_size : sec.type.min_size
          ele.sec = :none if ele.size < min_size
        end
      end
    end

    private def reassign_enclosed_elements : Nil
      offset = 0
      @residues
        .each_secondary_structure(strict: false)
        .each_cons(3, reuse: true) do |(left, ele, right)|
          if ele[0].sec.type.coil? &&
             left[0].sec.type.regular? &&
             left[0].sec.type == right[0].sec.type
            seclist = @raw_sec[offset + left.size, ele.size]
            ele.sec = seclist if seclist.all?(&.type.==(left[0].sec.type))
          end
          offset += left.size
        end
    end

    private def update_bridged_residues
      kdtree = Spatial::KDTree.new @residues.atoms
      @bridged_residues.clear
      @residues.each do |residue|
        next if residue.name == "PRO" && residue.in?(@bridged_residues)
        next unless donor = residue.dig?("N")
        h = residue.dig?("H").try(&.coords) || guess_hydrogen(residue)
        kdtree.each_neighbor(h, within: HBOND_DISTANCE.end) do |acceptor|
          if acceptor.residue != residue &&
             acceptor.name == "O" &&
             (residue.chain != acceptor.chain ||
             (residue.number - acceptor.residue.number).abs >= MIN_RESIDUE_DISTANCE) &&
             Spatial.distance(h, acceptor.coords).in?(HBOND_DISTANCE) &&
             Spatial.angle(donor.coords, h, acceptor.coords) >= HBOND_MIN_ANGLE
            @bridged_residues << residue << acceptor.residue
          end
        end
      end
    end

    private struct Basin
      getter sec : SecondaryStructure
      getter x0 : Float64
      getter y0 : Float64
      getter sigma_x : Float64
      getter sigma_y : Float64
      getter height : Float64
      getter theta : Float64
      getter offset : Float64

      @a : Float64
      @b : Float64
      @c : Float64

      def initialize(@sec : SecondaryStructure,
                     @x0 : Float64,
                     @y0 : Float64,
                     @sigma_x : Float64,
                     @sigma_y : Float64,
                     @height : Float64,
                     @theta : Float64,
                     @offset : Float64)
        @a = (Math.cos(@theta)**2) / (2*@sigma_x**2) + (Math.sin(@theta)**2) / (2*@sigma_y**2)
        @b = -(Math.sin(2*@theta)) / (4*@sigma_x**2) + (Math.sin(2*@theta)) / (4*@sigma_y**2)
        @c = (Math.sin(@theta)**2) / (2*@sigma_x**2) + (Math.cos(@theta)**2) / (2*@sigma_y**2)
      end

      def eval(x : Float64, y : Float64) : Float64
        @height * eval_exp(x - @x0, y - @y0) + @offset
      end

      def diff(x : Float64, y : Float64) : Tuple(Float64, Float64)
        dx = x - @x0
        dy = y - @y0
        e = eval_exp(dx, dy)
        {@height * (-2*dx*@a - dy*2*@b) * e, @height * (-2*dy*@c - dx*2*@b) * e}
      end

      def includes?(x : Float64, y : Float64) : Bool
        rotcos = Math.cos -@theta
        rotsin = Math.sin -@theta
        (rotcos * (x - @x0) + rotsin * (y - @y0))**2 / @sigma_x**2 +
          (rotsin * (x - @x0) - rotcos * (y - @y0))**2 / @sigma_y**2 <= 4.5
      end

      private def eval_exp(dx : Float64, dy : Float64) : Float64
        Math.exp -(@a*dx**2 + 2*@b*dx*dy + @c*dy**2)
      end
    end

    private class EnergySurface
      @basin_table : Hash(SecondaryStructure, Basin)

      def initialize(@basins : Array(Basin))
        @basin_table = @basins.index_by &.sec
      end

      def basin(sec : SecondaryStructure) : Basin
        @basin_table[sec]
      end

      def basin(x : Float64, y : Float64) : Basin?
        nearest_basin = nil
        min_distance = Float64::MAX
        @basins.each do |basin|
          d = (x - basin.x0)**2 + (y - basin.y0)**2
          if d < min_distance
            nearest_basin = basin
            min_distance = d
          end
        end
        nearest_basin
      end

      def diff(x : Float64, y : Float64) : Tuple(Float64, Float64)
        dx, dy = 0.0, 0.0
        @basins.each do |basin|
          dx_, dy_ = basin.diff(x, y)
          dx += dx_
          dy += dy_
        end
        {dx, dy}
      end

      def walk(x : Float64, y : Float64, steps : Int = 10, gamma : Float = 2.5e-4) : Tuple(Float64, Float64)
        steps.times do
          dx, dy = diff(x, y)
          x += dx * gamma
          y += dy * gamma
        end
        {x, y}
      end
    end

    class SecondaryStructureBlender
      def initialize(@residues : ResidueView)
        @patches = {} of Int32 => SecondaryStructure
      end

      def [](i : Int32, offset : Int32 = 0) : SecondaryStructure?
        i += offset
        @residues.unsafe_fetch(i).sec if 0 <= i < @residues.size
      end

      def beginning_of_sec_at?(i : Int32) : Bool
        self[i] != self[i, -1] && self[i] == self[i, 1] && self[i] == self[i, 2]
      end

      def blend : Nil
        if @residues.size > 2
          until next_patches.empty?
            @patches.each do |i, sec|
              @residues[i].sec = sec
            end
          end
        else
          @residues.sec = @residues[0].sec
        end
      end

      def end_of_sec_at?(i : Int32) : Bool
        self[i] == self[i, -2] && self[i] == self[i, -1] && self[i] != self[i, 1]
      end

      def middle_of_sec_at?(i : Int32) : Bool
        self[i] == self[i, -1] && self[i] == self[i, 1]
      end

      def mutable?(i : Int32) : Bool
        !beginning_of_sec_at?(i) &&
          !middle_of_sec_at?(i) &&
          !end_of_sec_at?(i)
      end

      def next_patches : Hash(Int32, SecondaryStructure)
        max_score = 0
        @patches.clear
        @residues.each_with_index do |res, i|
          next unless mutable?(i)
          score_table(i).each do |sec, score|
            if score > max_score
              @patches.clear
              max_score = score
            end
            @patches[i] = sec if score == max_score
          end
        end
        # aviods a swap (XY -> YX) by removing the substitution at the
        # left-most position
        @patches.reject! { |i, sec| @patches[i + 1]? == self[i] && sec == self[i + 1] }
        @patches
      end

      def score(i : Int32, sec : SecondaryStructure) : Int32
        score = (-2..2).sum do |offset|
          if offset == 0
            0
          elsif other = self[i, offset]
            other == sec ? 10**(3 - offset.abs) : 0
          else
            1
          end
        end
        score -= 5 if @residues[i].sec == self[i, 3]
        score
      end

      def score_table(i : Int32) : Hash(SecondaryStructure, Int32)
        (-2..2)
          .compact_map { |offset| self[i, offset] if offset != 0 }
          .uniq!
          .reject!(&.==(@residues.unsafe_fetch(i).sec))
          .to_h { |sec| {sec, score(i, sec)} }
      end
    end
  end
end
