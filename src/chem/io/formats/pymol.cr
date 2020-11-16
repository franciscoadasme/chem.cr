module Chem::PyMOL
  @[IO::FileType(format: PyMOL, ext: %w(pml))]
  class Writer < IO::Writer(Structure)
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

    def initialize(io : ::IO | Path | String,
                   @path : String | Path | Nil = nil,
                   *,
                   sync_close : Bool = false)
      super io, sync_close: sync_close
    end

    def write(structure : Structure) : Nil
      check_open
      write_header
      structure.each_secondary_structure do |residues, sec|
        next unless code = CODES[sec]?
        ch = residues[0].chain.id
        first = residues[0].number
        last = residues[-1].number
        sel = %(chain #{ch} and resi #{first}-#{last})
        @io.puts "alter #{sel}, ss = '#{code}'"
        @io.puts "color col-#{SHORT_NAMES[sec]}, #{sel}"
      end
      @io.puts "zoom all"
    end

    private def write_header : Nil
      @io.puts "load #{@path}" if @path
      @io.puts <<-EOS
        hide everything
        show cartoon
        bg_color white
        set_color col-protein, [200, 200, 200]
        set_color col-310, [232, 139, 196]
        set_color col-alpha, [228, 26, 28]
        set_color col-gamma, [200, 200, 200]
        set_color col-pi, [106, 61, 155]
        set_color col-pp, [256, 127, 0]
        set_color col-strand, [128, 77, 0]
        color col-protein, all
        alter all, ss = '0'
        EOS
    end
  end
end
