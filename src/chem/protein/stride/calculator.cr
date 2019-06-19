module Chem::Protein::Stride
  class Calculator
    def initialize(@structure : Structure)
    end

    def assign
      pdbfile = write_input
      output = exec_stride pdbfile.path
      parse_and_assign output
    ensure
      pdbfile.delete if pdbfile
    end

    private def exec_stride(pdbfile : String) : String
      exec = ENV["STRIDE_BIN"]? || Process.find_executable("stride")
      if exec && File.executable?(exec)
        output = `"#{exec}" #{pdbfile}`
        raise "stride executable failed" unless output.includes? "ASG"
        output
      else
        raise "Cannot find stride executable"
      end
    end

    private def parse_and_assign(output : String) : Nil
      output.each_line do |line|
        next unless line.starts_with? "ASG"
        chain = (chr = line[9]) != '-' ? chr : '-'
        resnum = line[10..14].to_i
        inscode = line[15]
        inscode = nil if inscode.whitespace?
        ss = SecondaryStructure[line[24]]
        @structure[chain][resnum, inscode].secondary_structure = ss
      end
    end

    private def write_input : File
      File.tempfile(".pdb") do |io|
        @structure.write io, format: :pdb
      end
    end
  end
end
