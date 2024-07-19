@[Chem::RegisterFormat(ext: %w(.stride))]
class Chem::Protein::Stride < Chem::Protein::SecondaryStructureCalculator
  class Writer
    include FormatWriter(Structure)

    @pdbid = "0000"

    protected def encode_entry(obj : Structure) : Nil
      check_open
      @pdbid = obj.experiment.try(&.pdb_accession.upcase) || "0000"

      header
      obj.experiment.try { |expt| info expt }
      summary obj
      detail obj
    end

    private def detail(residue : Residue)
      record "ASG", "%3s %1s %4d %4d    %1s   %11s   %7.2f   %7.2f   %7.1f",
        residue.name,
        residue.chain.id,
        residue.number,
        residue.number,
        residue.sec.regular? ? residue.sec.code : 'C',
        secname(residue.sec),
        residue.phi? || 360,
        residue.psi? || 360,
        0
    end

    private def detail(structure : Structure)
      title "Detailed secondary structure assignment"
      remark "|---Residue---|    |--Structure--|   |-Phi-|   |-Psi-|  |-Area-|"
      structure.residues.each do |residue|
        detail residue if residue.protein?
      end
    end

    private def header
      spacer '-'
      spacer
      remark "PSIQUE: Protein Secondary structure Identification on the basis"
      remark "of QUaternions and Electronic structure calculations"
      spacer
      remark "Please cite:"
      remark "Adasme-Carreño, F., et al., J. Chem. Inf. Model., 61(4), 1789-1800"
    end

    private def info(expt : Structure::Experiment)
      title "General information"
      record "HDR", "%-40s%9s   %4s",
        nil, # classification
        expt.deposition_date.to_s("%d-%^b-%y"),
        @pdbid
    end

    private def loc(residues : ResidueView)
      record "LOC", "%-12s %3s %5d %c      %3s  %5d %c",
        secname(residues[0].sec),
        residues[0].name,
        residues[0].number,
        residues[0].chain.id,
        residues[-1].name,
        residues[-1].number,
        residues[-1].chain.id
    end

    private def record(name : String, & : ->)
      @io << name << ' ' << ' '
      yield
      @io << ' ' << ' ' << @pdbid << '\n'
    end

    private def record(name : String, str : String, *args)
      record(name) do
        str = str % args unless args.empty?
        str.ljust @io, 68, ' '
      end
    end

    private def remark(str : String)
      record "REM", str
    end

    private def secname(sec : Protein::SecondaryStructure) : String
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

    private def secorder(sec : Protein::SecondaryStructure) : Int32
      case sec
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
    end

    private def seq(residues : ResidueView)
      residues.in_groups_of(50, reuse: true) do |residues|
        residues = residues.compact
        spacer
        remark "     " + (".".rjust(10) * (residues.size / 10).to_i)
        seq = residues.join { |r| r.template.try(&.code) || 'X' }
        record "SEQ", "%-4d %-50s %4d", residues[0].number, seq, residues[-1].number
        seq = residues.join { |r| r.sec.regular? ? r.sec.code : ' ' }
        record "STR", "     %-50s", seq
      end
      spacer
    end

    private def spacer(char : Char = ' ')
      record "REM" do
        "".center @io, 68, char
      end
    end

    private def summary(structure : Structure)
      title "Secondary structure summary"
      structure.chains.each do |chain|
        record "CHN", "%s %c", structure.source_file.try(&.basename), chain.id
        seq chain.residues
      end
      2.times { spacer }
      structure.residues.secondary_structures
        .select!(&.[0].sec.regular?)
        .sort_by { |residues| {secorder(residues[0].sec), residues[0].number} }
        .each do |residues|
          loc residues
        end
    end

    private def title(str : String)
      spacer
      record "REM" do
        " #{str} ".center @io, 68, '-'
      end
      spacer
    end
  end
end
