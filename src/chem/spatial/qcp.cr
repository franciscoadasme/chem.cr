module Chem::Spatial
  # Returns the minimum root mean square deviation (RMSD) in Å between
  # two sets of coordinates *pos* and *ref_pos* computed using the
  # quaternion-based characteristic polynomial (QCP) method
  # [Theobald2005].
  #
  # The QCP method is among the fastest known methods to determine the
  # optimal least-squares rotation matrix between the two coordinate
  # sets. The algorithm defines the problem of superposition as finding
  # the root of a quaternion-based characteristic polynomial of a "key"
  # matrix. Such approach avoids the costly eigen decomposition and
  # matrix inversion operations, which are commonly employed in other
  # methods.
  #
  # In the QCP method, the RMSD is first evaluated by solving for the
  # most positive eigenvalue of the 4×4 key matrix using a
  # Newton-Raphson algorithm that quickly finds the largest root
  # (eigenvalue) from the characteristic polynomial. The minimum RMSD is
  # then easily calculated from the largest eigenvalue. If not `nil`,
  # the *weights* determine the relative weights of each coordinate when
  # calculating the intermediate inner products.
  #
  # If the optimal rotation matrix is also desired, then the best
  # rotation is given by the corresponding eigenvector, which can be
  # calculated from a column of the adjoint matrix [Liu2009]. In such
  # case, the method expects a valid pointer (*out_rotmat*) pointing to
  # a nine float memory chunk for representing a 3x3 matrix (e.g.,
  # `Mat3.identity.to_unsafe`). Otherwise, the operations to obtain such
  # matrix would be skipped thus speeding up the RMSD calculation.
  #
  # Reference C implementation found at
  # [https://theobald.brandeis.edu/qcp]().
  #
  # WARNING: Coordinate sets must be centered at the origin.
  #
  # NOTE: Prefer using the `Spatial.rmsd` methods, which takes care of
  # centering the coordinates and whether or not the coordinate sets
  # should be superimposed first.
  #
  # ### References
  #
  # - [[Theobald2005](https://dx.doi.org/10.1107/S0108767305015266)]
  #   Theobald, D. L. Rapid calculation of RMSDs using a
  #   quaternion-based characteristic polynomial. *Acta Cryst.*,
  #   **2005**, *A61*, 478–480.
  # - [[Liu2009](https://dx.doi.org/10.1002/jcc.21439)] Liu, P.,
  #   Agrafiotis, D. K., & Theobald, D. L. Fast determination of the
  #   optimal rotational matrix for macromolecular superpositions. *J.
  #   Comput. Chem.*, **2010**, *31* (7), 1561–1563.
  def self.qcp(
    pos : Indexable(Vec3),
    ref_pos : Indexable(Vec3),
    weights : Indexable(Float64)? = nil,
    out_rotmat : Pointer(Float64)? = nil
  ) : Float64
    raise ArgumentError.new("Incompatible coordinates") if pos.size != ref_pos.size
    g1, g2, m = inner_products(pos, ref_pos, weights)

    # Compute coefficients (c0, c1, c2) of the characteristic quadratic
    # polynomial. This could be moved to a method, but several
    # operations are cached that are also used for the rotation matrix.
    sxx, sxy, sxz, syx, syy, syz, szx, szy, szz = m

    sxx2 = sxx ** 2
    syy2 = syy ** 2
    szz2 = szz ** 2
    sxy2 = sxy ** 2
    syz2 = syz ** 2
    sxz2 = sxz ** 2
    syx2 = syx ** 2
    szy2 = szy ** 2
    szx2 = szx ** 2

    syzszymsyyszz2 = 2.0 * (syz * szy - syy * szz)
    sxx2syy2szz2syz2szy2 = syy2 + szz2 - sxx2 + syz2 + szy2

    sxzpszx = sxz + szx
    syzpszy = syz + szy
    sxypsyx = sxy + syx
    syzmszy = syz - szy
    sxzmszx = sxz - szx
    sxymsyx = sxy - syx
    sxxpsyy = sxx + syy
    sxxmsyy = sxx - syy

    c2 = -2.0 * (sxx2 + syy2 + szz2 + sxy2 + syx2 + sxz2 + szx2 + syz2 + szy2)
    c1 = 8.0 * (sxx*syz*szy + syy*szx*sxz + szz*sxy*syx - sxx*syy*szz - syz*szx*sxy - szy*syx*sxz)
    c0 = (sxy2 + sxz2 - syx2 - szx2) ** 2 +                                                            # D
         (sxx2syy2szz2syz2szy2 + syzszymsyyszz2) * (sxx2syy2szz2syz2szy2 - syzszymsyyszz2) +           # E
         (-sxzpszx*syzmszy + sxymsyx*(sxxmsyy - szz)) * (-sxzmszx*syzpszy + sxymsyx*(sxxmsyy + szz)) + # F
         (-sxzpszx*syzpszy - sxypsyx*(sxxpsyy - szz)) * (-sxzmszx*syzmszy - sxypsyx*(sxxpsyy + szz)) + # G
         (+sxypsyx*syzpszy + sxzpszx*(sxxmsyy + szz)) * (-sxymsyx*syzmszy + sxzpszx*(sxxpsyy + szz)) + # H
         (+sxypsyx*syzmszy + sxzmszx*(sxxmsyy - szz)) * (-sxymsyx*syzpszy + sxzmszx*(sxxpsyy - szz))   # I

    l_max = find_largest_root((g1 + g2) * 0.5, c0, c1, c2)
    rmsd = Math.sqrt ((g1 + g2 - 2 * l_max) / pos.size).abs
    return rmsd unless out_rotmat

    # Compute rotation matrix according to liu2009, where the rotation
    # matrix corresponds to the eigenvector associated with the largest
    # eigenvalue of the key matrix *K*. The eigenvector can be computed
    # from any nonzero column of the adjoint of the matrix *K - l_maxI*.

    # Define the matrix *K - l_maxI*
    k11 = sxxpsyy + szz - l_max
    k12 = syzmszy
    k13 = -sxzmszx
    k14 = sxymsyx
    k21 = syzmszy
    k22 = sxxmsyy - szz - l_max
    k23 = sxypsyx
    k24 = sxzpszx
    k31 = k13
    k32 = k23
    k33 = syy - sxx - szz - l_max
    k34 = syzpszy
    k41 = k14
    k42 = k24
    k43 = k34
    k44 = szz - sxxpsyy - l_max

    k3344_4334 = k33 * k44 - k43 * k34
    k3244_4234 = k32 * k44 - k42 * k34
    k3243_4233 = k32 * k43 - k42 * k33
    k3143_4133 = k31 * k43 - k41 * k33
    k3144_4134 = k31 * k44 - k41 * k34
    k3142_4132 = k31 * k42 - k41 * k32

    # Compute the eigenvector from the adjoint matrix. Ensure a nonzero
    # eigenvector by calculating another column if the norm of the
    # current one is too small. According to liu2009, this happens very
    # rarely but better to be safe.
    #
    # Adapted from MDAnalysis code.
    q1 = k22 * k3344_4334 - k23 * k3244_4234 + k24 * k3243_4233
    q2 = -k21 * k3344_4334 + k23 * k3144_4134 - k24 * k3143_4133
    q3 = k21 * k3244_4234 - k22 * k3144_4134 + k24 * k3142_4132
    q4 = -k21 * k3243_4233 + k22 * k3143_4133 - k23 * k3142_4132
    qabs2 = q1**2 + q2**2 + q3**2 + q4**2

    if qabs2 < 1e-6
      q1 = k12*k3344_4334 - k13*k3244_4234 + k14*k3243_4233
      q2 = -k11*k3344_4334 + k13*k3144_4134 - k14*k3143_4133
      q3 = k11*k3244_4234 - k12*k3144_4134 + k14*k3142_4132
      q4 = -k11*k3243_4233 + k12*k3143_4133 - k13*k3142_4132
      qabs2 = q1**2 + q2**2 + q3**2 + q4**2

      if qabs2 < 1e-6
        k1324_1423 = k13 * k24 - k14 * k23
        k1224_1422 = k12 * k24 - k14 * k22
        k1223_1322 = k12 * k23 - k13 * k22
        k1124_1421 = k11 * k24 - k14 * k21
        k1123_1321 = k11 * k23 - k13 * k21
        k1122_1221 = k11 * k22 - k12 * k21

        q1 = k42 * k1324_1423 - k43 * k1224_1422 + k44 * k1223_1322
        q2 = -k41 * k1324_1423 + k43 * k1124_1421 - k44 * k1123_1321
        q3 = k41 * k1224_1422 - k42 * k1124_1421 + k44 * k1122_1221
        q4 = -k41 * k1223_1322 + k42 * k1123_1321 - k43 * k1122_1221
        qabs2 = q1**2 + q2**2 + q3**2 + q4**2

        if qabs2 < 1e-6
          q1 = k32 * k1324_1423 - k33 * k1224_1422 + k34 * k1223_1322
          q2 = -k31 * k1324_1423 + k33 * k1124_1421 - k34 * k1123_1321
          q3 = k31 * k1224_1422 - k32 * k1124_1421 + k34 * k1122_1221
          q4 = -k31 * k1223_1322 + k32 * k1123_1321 - k33 * k1122_1221
          qabs2 = q1**2 + q2**2 + q3**2 + q4**2

          if qabs2 < 1e-6 # no more columns so return the identity matrix
            out_rotmat.clear 9
            out_rotmat[0] = out_rotmat[4] = out_rotmat[8] = 1.0
            return rmsd
          end
        end
      end
    end

    # Transform the eigenvector (quaternion) into the corresponding
    # rotation matrix.
    #
    # TODO: could be refactored to `quat.to_mat3` or something like
    # that?
    qabs = Math.sqrt qabs2
    q1 /= qabs
    q2 /= qabs
    q3 /= qabs
    q4 /= qabs

    w2 = q1**2
    x2 = q2**2
    y2 = q3**2
    z2 = q4**2

    wx = q1 * q2
    wy = q1 * q3
    wz = q1 * q4
    xy = q2 * q3
    xz = q4 * q2
    yz = q3 * q4

    out_rotmat[0] = w2 + x2 - y2 - z2
    out_rotmat[1] = 2 * (xy + wz)
    out_rotmat[2] = 2 * (xz - wy)
    out_rotmat[3] = 2 * (xy - wz)
    out_rotmat[4] = w2 - x2 + y2 - z2
    out_rotmat[5] = 2 * (yz + wx)
    out_rotmat[6] = 2 * (xz + wy)
    out_rotmat[7] = 2 * (yz - wx)
    out_rotmat[8] = w2 - x2 - y2 + z2

    rmsd
  end

  # Returns the largest root (eigenvalue) of the characteristic
  # quadratic polynomial using the Newton-Raphson algorithm.
  #
  # The characteristic equation to solve has the form:
  #
  #     P(λ) = λ⁴ + C₂λ² + C₁λ + C₀ = 0
  #
  # The algorithm will set initial guess to *lambda* and it will stop at
  # *max_iter* iterations or when reached the convergence threshold
  # *rtol*.
  private def self.find_largest_root(lambda, c0, c1, c2, max_iter = 50, rtol = 1e-6)
    max_iter.times do
      prev_lambda = lambda
      lambdk2 = lambda**2
      b = (lambdk2 + c2) * lambda
      a = b + c1
      lambda -= (a * lambda + c0) / (2.0 * lambdk2 * lambda + b + a)
      break if (lambda - prev_lambda).abs < (rtol * lambda).abs
    end
    lambda
  end

  # Returns the intermediate unweighted inner products of each
  # coordinate set (G1 and G2) and the inner product between the
  # coordinate sets (M).
  private def self.inner_products(pos, ref_pos, weights : Nil)
    m = StaticArray(Float64, 9).new(0.0)
    g1 = g2 = 0.0

    ref_pos.size.times do |i|
      v1 = ref_pos.unsafe_fetch(i)
      v2 = pos.unsafe_fetch(i)

      g1 += v1.abs2
      g2 += v2.abs2

      m[0] += v1.x * v2.x
      m[1] += v1.x * v2.y
      m[2] += v1.x * v2.z

      m[3] += v1.y * v2.x
      m[4] += v1.y * v2.y
      m[5] += v1.y * v2.z

      m[6] += v1.z * v2.x
      m[7] += v1.z * v2.y
      m[8] += v1.z * v2.z
    end

    {g1, g2, m}
  end

  # Returns the intermediate weighted inner products of each coordinate
  # set (G1 and G2) and the inner product between the coordinate sets
  # (M).
  private def self.inner_products(pos, ref_pos, weights)
    m = StaticArray(Float64, 9).new(0.0)
    g1 = g2 = 0.0

    ref_pos.size.times do |i|
      v1 = ref_pos.unsafe_fetch(i)
      v2 = pos.unsafe_fetch(i)
      weight = weights.unsafe_fetch(i)

      g1 += v1.abs2 * weight
      g2 += v2.abs2 * weight

      v1 *= weight

      m[0] += v1.x * v2.x
      m[1] += v1.x * v2.y
      m[2] += v1.x * v2.z

      m[3] += v1.y * v2.x
      m[4] += v1.y * v2.y
      m[5] += v1.y * v2.z

      m[6] += v1.z * v2.x
      m[7] += v1.z * v2.y
      m[8] += v1.z * v2.z
    end

    {g1, g2, m}
  end
end
