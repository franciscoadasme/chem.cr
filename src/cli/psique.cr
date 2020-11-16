require "option_parser"
require "../chem"

VERSION      = "1.1.1"
VERSION_DATE = "2020-11-16"

input_file = ""
output_file = STDOUT
output_type = "structure"
beta = ""
OptionParser.parse do |parser|
  parser.banner = "Usage: psique [-o|--output PDB] PDB"
  parser.on("-b", "--beta", "Write curvature value to PDB beta column") do
    beta = "curvature"
  end
  parser.on("--pymol", "Write a PyMOL commnad script (*.pml) file") do
    output_type = "pymol"
  end
  parser.on("--vmd", "Write a VMD commnad script (*.vmd) file") do
    output_type = "vmd"
  end
  parser.on("--stride", "Write a STRIDE output (*.stride) file") do
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
      PSIQUE: Protein Secondary structure Identification on the basis of
      QUaternions and Electronic structure calculations

      PSIQUE is a geometry-based secondary structure assignment method that
      uses local helix paramaters, quaternions, and a classification criterion
      derived from DFT calculations of polyalanine. The algorithm can identify
      common (alpha-, 3_10-, pi-helices and and beta-strand) and rare (PP-II
      ribbon helix and gamma-helices) secondary structures, including
      handedness if appropiate.

      The information of the protein secondary structure is written in the PDB
      header. Special codes are used for some structures not included in the
      standard format: 11 for left-handed 3_10-helix and 13 for left-handed
      pi-helix. Alternatively, output can be written in other file formats
      that can be read in analysis and visualization packages.

      Please cite:
      F. Adasme-Carreño, et al., XXXXXX, XXXX, X (XX), XXX-XXX
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
