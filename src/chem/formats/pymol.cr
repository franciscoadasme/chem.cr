# TODO: drop this as a format.
@[Chem::RegisterFormat(ext: %w(.pml), module_api: true)]
module Chem::PyMOL
  # Writes a PyMOL Macro Language (PML) script to *io*.
  #
  # The script will load the source file (read from `Structure#source_file`) and display the secondary structure in the Cartoon representation.
  # Secondary structure is overridden via the `ss` property based on the current secondary structure (see `Residue#sec`).
  # Custom colors are set for the secondary structure types.
  #
  # TODO: add colors to the docs.
  def self.write(io : IO | Path | String, struc : Structure) : Nil
    Writer.open(io) do |writer|
      writer << struc
    end
  end

  class Writer
    include FormatWriter(Structure)

    CODES = {
      Protein::SecondaryStructure::BetaStrand            => 'S',
      Protein::SecondaryStructure::LeftHandedHelix3_10   => 'H',
      Protein::SecondaryStructure::LeftHandedHelixAlpha  => 'H',
      Protein::SecondaryStructure::LeftHandedHelixGamma  => 'H',
      Protein::SecondaryStructure::LeftHandedHelixPi     => 'H',
      Protein::SecondaryStructure::RightHandedHelix3_10  => 'H',
      Protein::SecondaryStructure::RightHandedHelixAlpha => 'H',
      Protein::SecondaryStructure::RightHandedHelixGamma => 'H',
      Protein::SecondaryStructure::RightHandedHelixPi    => 'H',
      Protein::SecondaryStructure::Polyproline           => 'H',
    }
    SHORT_NAMES = {
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

    protected def encode_entry(obj : Structure) : Nil
      check_open
      header obj.source_file
      obj.residues.each_secondary_structure do |residues, sec|
        next unless code = CODES[sec]?
        ch = residues[0].chain.id
        first = residues[0].number
        last = residues[-1].number
        sel = %(chain #{ch} and resi #{first}-#{last})
        @io.puts "alter #{sel}, ss = '#{code}'"
        @io.puts "color col-#{SHORT_NAMES[sec]}, #{sel}"
      end
    end

    private def header(source_file : Path?)
      @io.puts "load #{source_file}" if source_file
      @io.puts <<-EOS
        set cartoon_discrete_colors, on
        hide everything
        show cartoon
        zoom all
        bg_color white
        set_color col-protein, #{seccolor(:none)}
        set_color col-310, #{seccolor(:right_handed_helix3_10)}
        set_color col-alpha, #{seccolor(:right_handed_helix_alpha)}
        set_color col-gamma, #{seccolor(:right_handed_helix_gamma)}
        set_color col-pi, #{seccolor(:right_handed_helix_pi)}
        set_color col-pp, #{seccolor(:polyproline)}
        set_color col-strand, #{seccolor(:beta_strand)}
        color col-protein, all
        alter all, ss = '0'
        EOS
    end

    private def seccolor(sec : Protein::SecondaryStructure) : Array(UInt8)
      sec.color.to_a
    end
  end
end
