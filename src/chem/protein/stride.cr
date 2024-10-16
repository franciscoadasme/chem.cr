module Chem::Protein::Stride
  def self.assign(struc : Structure) : Nil
    struc.residues.sec = :none
    run_stride(struc).each_line do |line|
      next unless line.starts_with? "ASG"
      chain = (chr = line[9]) != '-' ? chr : '-'
      inscode = line[14]
      inscode = nil unless inscode.letter?
      resnum = line[inscode.nil? ? 10..14 : 10..13].to_i
      struc.dig(chain, resnum, inscode).sec = SecondaryStructure[line[24]]
    end
  end

  private def self.exec_stride(pdbfile : String) : String
    exec = ENV["STRIDE_BIN"]? || Process.find_executable("stride")
    if exec && File.executable?(exec)
      output = `"#{exec}" #{pdbfile}`
      raise "stride executable failed" unless "ASG".in?(output)
      output
    else
      raise "Cannot find stride executable"
    end
  end

  private def self.run_stride(struc : Structure) : String
    pdbfile = File.tempfile(".pdb") do |io|
      struc.to_pdb io
    end
    exec_stride pdbfile.path
  ensure
    pdbfile.delete if pdbfile
  end
end
