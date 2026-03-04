# TODO: drop this as a format.
@[Chem::RegisterFormat(ext: %w(.vmd))]
module Chem::VMD
  # Writes a VMD command script to *io*.
  #
  # The script will load the source file (read from `Structure#source_file`) and display the secondary structure in the Cartoon representation.
  # Custom colors are set for the secondary structure types.
  #
  # TODO: add colors to the docs.
  def self.write(io : IO, struc : Structure) : Nil
    io.puts <<-EOS
      display resetview
      color Structure "Alpha Helix" 29
      color change rgb 29 #{color_to_vmd(:right_handed_helix_alpha)}
      color Structure "3_10_Helix" 13
      color change rgb 13 #{color_to_vmd(:right_handed_helix3_10)}
      color Structure "Pi_Helix" 11
      color change rgb 11 #{color_to_vmd(:right_handed_helix_pi)}
      # used for gamma-helix
      color Structure "Bridge_Beta" 32
      color change rgb 32 #{color_to_vmd(:right_handed_helix_gamma)}
      # used for polyproline
      color Structure "Turn" 17
      color change rgb 17 #{color_to_vmd(:polyproline)}
      color Structure "Extended_Beta" 20
      color change rgb 20 #{color_to_vmd(:beta_strand)}
      color Structure "Coil" 6
      color change rgb 6 #{color_to_vmd(:none)}
      color Display Background white
      EOS
    io.puts "mol new #{struc.source_file}" if struc.source_file
    io.puts <<-EOS
      mol delrep top top
      mol representation NewCartoon
      mol color Structure
      mol addrep top
      EOS
    struc.residues.each_secondary_structure do |residues, sec|
      ch = residues[0].chain.id
      first = residues[0].number
      last = residues[-1].number
      sel = "chain #{ch} and resid #{first} to #{last}"
      code = case sec
             when .helix_alpha? then 'H'
             when .helix3_10?   then 'G'
             when .helix_pi?    then 'I'
             when .helix_gamma? then 'B'
             when .polyproline? then 'T'
             when .beta_strand? then 'E'
             else                    'C'
             end
      io.puts %([atomselect top "#{sel}"] set structure #{code})
    end
  end

  define_file_overload(VMD, write, mode: "w")

  private def self.color_to_vmd(sec : Protein::SecondaryStructure) : String
    sec.color.to_a.map(&./(255).round(3)).join ' '
  end
end
