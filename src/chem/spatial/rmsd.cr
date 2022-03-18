module Chem::Spatial
  # Returns the weighted root mean square deviation (RMSD) in Å between
  # two sets of coordinates *pos* and *ref_pos*.
  #
  # The RMSD is defined as the weighted average Euclidean distance
  # between the two coordinates sets *A* and *B*. The *weights* (e.g.,
  # atom masses) determine the relative weights of each coordinate when
  # calculating the RMSD.
  #
  # If the minimum RMSD is desired (*minimize* is `true`), the RMSD will
  # be computed using the quaternion-based characteristic polynomial
  # (QCP) method (refer to `.qcp`). This method superimpose *pos* onto
  # *ref_pos* by computing the optimal rotation between the two
  # coordinate sets before calculating the RMSD.
  def self.rmsd(
    pos : CoordinatesProxy,
    ref_pos : CoordinatesProxy,
    weights : Indexable(Float64),
    minimize : Bool = false
  ) : Float64
    pos = pos.to_a         # FIXME: avoid copying coordinates
    ref_pos = ref_pos.to_a # FIXME: avoid copying coordinates
    raise ArgumentError.new("Incompatible coordinates") if pos.size != ref_pos.size

    if minimize
      # requires that the coordinates are centered at origin
      # FIXME: replace by pos.dup.center_at_origin(weights)
      center = pos.average(weights)
      pos.map! &.-(center)
      center = ref_pos.average(weights)
      ref_pos.map! &.-(center)

      # weights should be relative to the mean
      weight_mean = weights.mean
      weights.map! &./(weight_mean)

      Spatial.qcp(pos, ref_pos, weights)
    else
      Math.sqrt((0...pos.size).average(weights) do |i|
        Spatial.distance2 pos.unsafe_fetch(i), ref_pos.unsafe_fetch(i)
      end)
    end
  end

  # Returns the root mean square deviation (RMSD) in Å between two sets
  # of coordinates *pos* and *ref_pos*.
  #
  # The RMSD is defined as the average Euclidean distance between the
  # two coordinates sets *A* and *B*.
  #
  # If the minimum RMSD is desired (*minimize* is `true`), the RMSD will
  # be computed using the quaternion-based characteristic polynomial
  # (QCP) method (refer to `.qcp`). This method superimpose *pos* onto
  # *ref_pos* by computing the optimal rotation between the two
  # coordinate sets before calculating the RMSD.
  def self.rmsd(
    pos : CoordinatesProxy,
    ref_pos : CoordinatesProxy,
    minimize : Bool = false
  ) : Float64
    pos = pos.to_a         # FIXME: avoid copying coordinates
    ref_pos = ref_pos.to_a # FIXME: avoid copying coordinates
    raise ArgumentError.new("Incompatible coordinates") if pos.size != ref_pos.size

    if minimize
      # requires that the coordinates are centered at origin
      # FIXME: replace by pos.dup.center_at_origin
      center = pos.mean
      pos.map! &.-(center)
      center = ref_pos.mean
      ref_pos.map! &.-(center)
      Spatial.qcp pos, ref_pos
    else
      Math.sqrt((0...pos.size).mean do |i|
        Spatial.distance2 pos.unsafe_fetch(i), ref_pos.unsafe_fetch(i)
      end)
    end
  end
end

module Chem::Spatial
  # Returns the root mean square deviation (RMSD) in Å between two atom
  # collections. This is a convenience overload so arguments are
  # forwarded to specific `.rmsd` methods.
  def self.rmsd(atoms : AtomCollection, other : AtomCollection, *args, **options)
    # TODO: add option to ensure to atom equivalency
    rmsd atoms.coords, other.coords, *args, **options
  end
end
