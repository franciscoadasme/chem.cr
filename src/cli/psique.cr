require "option_parser"
require "../chem"

VERSION      = "1.0.1"
VERSION_DATE = "2020-11-15"

input_file = ""
output_file = STDOUT
output_type = "structure"
beta = ""
OptionParser.parse do |parser|
  parser.banner = "Usage: psique [-o|--output PDB] PDB"
  parser.on("-b", "--beta", "Write curvature value to PDB beta column") do
    beta = "curvature"
  end
  parser.on("--pymol", "Write a PyMOL Commnad Script (*.pml) file") do
    output_type = "pymol"
  end
  parser.on("--vmd", "Write a VMD Commnad Script (*.vmd) file") do
    output_type = "vmd"
  end
  parser.on("--stride", "Use STRIDE output (*.stride) file format") do
    output_type = "stride"
  end
  parser.on("-o OUTPUT", "--output OUTPUT", "Output file") do |str|
    output_file = str
  end
  parser.on("-f OUTPUT", "Alias for -o/--output") do |str|
    output_file = str
  end
  parser.on("-h", "--help", "Show this help") do
    puts <<-EOS
      PSIQUE is a protein secondary structure assignment based on local helix
      paramaters, quaternions, and a quantum-mechanical energy-driven criterion
      for secondary structure classification. The algorithm can identify six
      classes (alpha-, 3_10-, pi- and gamma-helices, PP-II ribbon helix, and
      beta-strand) and their handedness.

      The information of the protein secondary structure is written in the PDB
      header. Special codes are used for some structures not included in the
      standard format: 11 for left-handed 3_10-helix and 13 for left-handed
      pi-helix.
      EOS
    puts
    puts parser
    exit
  end
  parser.on("--version", "show version") do
    puts "PSIQUE #{VERSION} (#{VERSION_DATE})"
  end

  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit
  end

  parser.unknown_args do |args, _|
    input_file = args[0]?
  end
end

abort "error: missing input file" unless input_file

begin
  structure = Chem::Structure.from_pdb input_file.not_nil!
  structure.each_residue do |residue|
    case beta
    when "curvature"
      curvature = 0.0
      if (h1 = residue.previous.try(&.hlxparams)) &&
         (h2 = residue.hlxparams) &&
         (h3 = residue.next.try(&.hlxparams))
        dprev = Chem::Spatial.distance h1.q, h2.q
        dnext = Chem::Spatial.distance h2.q, h3.q
        curvature = ((dprev + dnext) / 2).degrees
      end
      residue.each_atom &.temperature_factor=(curvature)
    end
  end
  Chem::Protein::PSIQUE.assign structure

  case output_type
  when "pymol"  then structure.to_pymol output_file, input_file.not_nil!
  when "vmd"    then structure.to_vmd output_file, input_file.not_nil!
  when "stride" then structure.to_stride output_file
  else               structure.to_pdb output_file
  end
rescue ex : Chem::IO::ParseException
  abort "error: #{ex} in #{input_file}"
end
