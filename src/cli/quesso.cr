require "option_parser"
require "../chem"

VERSION      = "1.0.0-rc"
VERSION_DATE = "2020-08-02"

input_file = ""
output_file = STDOUT
OptionParser.parse do |parser|
  parser.banner = "Usage: quesso [-o|--output PDB] PDB"
  parser.on("-o OUTPUT", "--output OUTPUT", "PDB output file") do |str|
    output_file = str
  end
  parser.on("-h", "--help", "Show this help") do
    puts <<-EOS
      QUESSO is a protein secondary structure assignment based on local helix
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
    puts "QUESSO #{VERSION} (#{VERSION_DATE})"
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
  Chem::Protein::QUESSO.assign structure
  structure.to_pdb output_file
rescue ex : Chem::IO::ParseException
  abort ex.to_s_with_location
end
