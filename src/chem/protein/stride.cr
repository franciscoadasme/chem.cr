module Chem::Protein
  class Stride < SecondaryStructureCalculator
    def initialize(@structure : Structure)
      @output = uninitialized String
    end

    def assign : Nil
      run_stride
      @output.each_line do |line|
        next unless line.starts_with? "ASG"
        chain = (chr = line[9]) != '-' ? chr : '-'
        inscode = line[14]
        inscode = nil unless inscode.letter?
        resnum = line[inscode.nil? ? 10..14 : 10..13].to_i
        @structure.dig(chain, resnum, inscode).sec = SecondaryStructure[line[24]]
      end
    end

    private def exec_stride(pdbfile : String) : String
      exec = ENVec3["STRIDE_BIN"]? || Process.find_executable("stride")
      if exec && File.executable?(exec)
        output = `"#{exec}" #{pdbfile}`
        raise "stride executable failed" unless "ASG".in?(output)
        output
      else
        raise "Cannot find stride executable"
      end
    end

    private def run_stride : Nil
      pdbfile = File.tempfile(".pdb") do |io|
        @structure.to_pdb io
      end
      @output = exec_stride pdbfile.path
    ensure
      pdbfile.delete if pdbfile
    end
  end
end
