module Chem::Protein::Stride
  class Calculator
    def initialize(@structure : Structure)
      @output = uninitialized String
    end

    def assign
      run_stride
      each_record do |chain, resnum, inscode, ss|
        @structure[chain][resnum, inscode].sec = ss
      end
    end

    def calculate : Hash(Residue, SecondaryStructure)
      run_stride
      ss_table = {} of Residue => SecondaryStructure
      each_record do |chain, resnum, inscode, ss|
        ss_table[@structure[chain][resnum, inscode]] = ss
      end
      ss_table
    end

    private def each_record(&block : Char, Int32, Char?, SecondaryStructure ->) : Nil
      @output.each_line do |line|
        next unless line.starts_with? "ASG"
        chain = (chr = line[9]) != '-' ? chr : '-'
        inscode = line[14]
        inscode = nil unless inscode.letter?
        resnum = line[inscode.nil? ? 10..14 : 10..13].to_i
        ss = SecondaryStructure[line[24]]
        yield chain, resnum, inscode, ss
      end
    end

    private def exec_stride(pdbfile : String) : String
      exec = ENV["STRIDE_BIN"]? || Process.find_executable("stride")
      if exec && File.executable?(exec)
        output = `"#{exec}" #{pdbfile}`
        raise "stride executable failed" unless "ASG".in?(output)
        output
      else
        raise "Cannot find stride executable"
      end
    end

    private def run_stride : Nil
      pdbfile = write_input
      @output = exec_stride pdbfile.path
    ensure
      pdbfile.delete if pdbfile
    end

    private def write_input : File
      File.tempfile(".pdb") do |io|
        @structure.to_pdb io
      end
    end
  end
end
