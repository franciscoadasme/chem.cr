# TODO: drop this as a format.
@[Chem::RegisterFormat(ext: %w(.stride))]
module Chem::Protein::Stride
  # Writes a structure to *io*.
  def self.write(io : IO, struc : Structure) : Nil
    pdbid = struc.experiment.try(&.pdb_accession) || "0000"

    io.printf "REM  %s  %s\n", "".ljust(68, '-'), pdbid
    io.printf "REM%76s\n", pdbid
    io.printf "REM  %-68s  %s\n", "PSIQUE: Protein Secondary structure Identification on the basis", pdbid
    io.printf "REM  %-68s  %s\n", "of QUaternions and Electronic structure calculations", pdbid
    io.printf "REM%76s\n", pdbid
    io.printf "REM  %-68s  %s\n", "Please cite:", pdbid
    io.printf "REM  %-68s  %s\n", "Adasme-Carreño, F., et al., J. Chem. Inf. Model., 61(4), 1789-1800", pdbid

    if expt = struc.experiment
      io.printf "REM%76s\n", pdbid
      io.printf "REM  %s  %s\n", " General information ".center(68, '-'), pdbid
      io.printf "REM%76s\n", pdbid
      io.printf "HDR%51s%7s%18s\n",
        expt.deposition_date.to_s("%d-%^b-%y"),
        expt.pdb_accession.upcase,
        pdbid
    end

    io.printf "REM%76s\n", pdbid
    io.printf "REM  %s  %s\n", " Secondary structure summary ".center(68, '-'), pdbid
    io.printf "REM%76s\n", pdbid
    struc.chains.each do |chain|
      io.printf "CHN  %s %c%64s\n", struc.source_file.try(&.basename), chain.id, pdbid
      # write sequence
      chain.residues.in_groups_of(50, reuse: true) do |residues|
        residues = residues.compact
        io.printf "REM%76s\n", pdbid
        io.printf "REM       "
        (residues.size // 10).times { ".".rjust io, 10 }
        io.printf "%#{75 - residues.size}s\n", pdbid
        seq = residues.join { |r| r.template.try(&.code) || 'X' }
        io.printf "SEQ  %-4d %-50s %4d%14s\n", residues[0].number, seq, residues[-1].number, pdbid
        seq = residues.join { |r| r.sec.regular? ? r.sec.code : ' ' }
        io.printf "STR       %-50s%19s\n", seq, pdbid
      end
      io.printf "REM%76s\n", pdbid
    end
    io.printf "REM%76s\n", pdbid
    io.printf "REM%76s\n", pdbid
    struc.residues.secondary_structures
      .select!(&.[0].sec.regular?)
      .sort_by do |residues|
        order = case residues[0].sec
                when .helix_alpha? then 1
                when .helix3_10?   then 2
                when .helix_pi?    then 3
                when .helix_gamma? then 4
                when .polyproline? then 5
                when .beta_strand? then 6
                when .beta_bridge? then 7
                when .turn?        then 8
                else                    Int32::MAX
                end
        {order, residues[0].number}
      end
      .each do |residues|
        io.printf "LOC  %-12s %3s %5d %c      %3s  %5d %c%32s\n",
          secname(residues[0].sec),
          residues[0].name,
          residues[0].number,
          residues[0].chain.id,
          residues[-1].name,
          residues[-1].number,
          residues[-1].chain.id,
          pdbid
      end

    io.printf "REM%76s\n", pdbid
    io.printf "REM  %s  %s\n", " Detailed secondary structure assignment ".center(68, '-'), pdbid
    io.printf "REM%76s\n", pdbid
    io.printf "REM  |---Residue---|    |--Structure--|   |-Phi-|   |-Psi-|  |-Area-|%10s\n", pdbid
    struc.residues.each do |residue|
      next unless residue.protein?
      io.printf "ASG  %3s %1s %4d %4d    %1s   %11s   %7.2f   %7.2f   %7.1f%10s\n",
        residue.name,
        residue.chain.id,
        residue.number,
        residue.number,
        residue.sec.regular? ? residue.sec.code : 'C',
        secname(residue.sec),
        residue.phi? || 360,
        residue.psi? || 360,
        0,
        pdbid
    end
  end

  define_file_overload(Stride, write, mode: "w")

  private def self.secname(sec : Protein::SecondaryStructure) : String
    case sec
    when .beta_bridge? then "Bridge"
    when .beta_strand? then "Strand"
    when .helix3_10?   then "310Helix"
    when .helix_alpha? then "AlphaHelix"
    when .helix_gamma? then "GammaHelix"
    when .helix_pi?    then "PiHelix"
    when .polyproline? then "PolyProline"
    when .turn?        then "Turn"
    else                    "Coil"
    end
  end
end
