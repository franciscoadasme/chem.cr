# TODO: drop this as a format.
@[Chem::RegisterFormat(ext: %w(.pml))]
module Chem::PyMOL
  # Writes a PyMOL Macro Language (PML) script to *io*.
  #
  # The script will load the source file (read from `Structure#source_file`) and display the secondary structure in the Cartoon representation.
  # Secondary structure is overridden via the `ss` property based on the current secondary structure (see `Residue#sec`).
  # Custom colors are set for the secondary structure types.
  #
  # TODO: add colors to the docs.
  def self.write(io : IO, struc : Structure) : Nil
    io.puts "load #{struc.source_file}" if struc.source_file
    SHORT_NAMES.each do |sec, short_name|
      io.puts "set_color col-#{short_name}, #{sec.color.to_a}"
    end
    io.puts <<-EOS
      set cartoon_discrete_colors, on
      hide everything
      show cartoon
      zoom all
      bg_color white
      color col-protein, all
      alter all, ss = '0'
      EOS

    struc.residues.each_secondary_structure do |residues, sec|
      code = case sec
             when .beta_strand?
               'S'
             when .left_handed_helix3_10?,
                  .left_handed_helix_alpha?,
                  .left_handed_helix_gamma?,
                  .left_handed_helix_pi?,
                  .right_handed_helix3_10?,
                  .right_handed_helix_alpha?,
                  .right_handed_helix_gamma?,
                  .right_handed_helix_pi?,
                  .polyproline?
               'H'
             else
               next
             end
      ch = residues[0].chain.id
      first = residues[0].number
      last = residues[-1].number
      sel = %(chain #{ch} and resi #{first}-#{last})
      io.puts "alter #{sel}, ss = '#{code}'"
      io.puts "color col-#{SHORT_NAMES[sec]}, #{sel}"
    end
  end

  define_file_overload(PyMOL, write, mode: "w")

  private SHORT_NAMES = {
    Protein::SecondaryStructure::BetaStrand            => "strand",
    Protein::SecondaryStructure::LeftHandedHelix3_10   => "310",
    Protein::SecondaryStructure::LeftHandedHelixAlpha  => "alpha",
    Protein::SecondaryStructure::LeftHandedHelixGamma  => "gamma",
    Protein::SecondaryStructure::LeftHandedHelixPi     => "pi",
    Protein::SecondaryStructure::RightHandedHelix3_10  => "310",
    Protein::SecondaryStructure::RightHandedHelixAlpha => "alpha",
    Protein::SecondaryStructure::RightHandedHelixGamma => "gamma",
    Protein::SecondaryStructure::RightHandedHelixPi    => "pi",
    Protein::SecondaryStructure::Polyproline           => "pp",
  }
end
