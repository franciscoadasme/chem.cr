module Chem::VMD
  @[RegisterFormat(format: VMD, ext: %w(vmd))]
  class Writer < FormatWriter(Structure)
    def initialize(io : ::IO | Path | String,
                   @path : String | Path | Nil = nil,
                   *,
                   sync_close : Bool = false)
      super io, sync_close: sync_close
    end

    def write(structure : Structure) : Nil
      check_open
      header
      structure.each_secondary_structure do |residues, sec|
        ch = residues[0].chain.id
        first = residues[0].number
        last = residues[-1].number
        sel = "chain #{ch} and resid #{first} to #{last}"
        @io.puts %([atomselect top "#{sel}"] set structure #{seccode(sec)})
      end
    end

    private def header : Nil
      @io.puts <<-EOS
        display resetview
        color Structure "Alpha Helix" 29
        color change rgb 29 #{seccolor(:right_handed_helix_alpha).join ' '}
        color Structure "3_10_Helix" 13
        color change rgb 13 #{seccolor(:right_handed_helix3_10).join ' '}
        color Structure "Pi_Helix" 11
        color change rgb 11 #{seccolor(:right_handed_helix_pi).join ' '}
        # used for gamma-helix
        color Structure "Bridge_Beta" 32
        color change rgb 32 #{seccolor(:right_handed_helix_gamma).join ' '}
        # used for polyproline
        color Structure "Turn" 17
        color change rgb 17 #{seccolor(:polyproline).join ' '}
        color Structure "Extended_Beta" 20
        color change rgb 20 #{seccolor(:beta_strand).join ' '}
        color Structure "Coil" 6
        color change rgb 6 #{seccolor(:none).join ' '}
        color Display Background white
        EOS
      @io.puts "mol new #{@path}" if @path
      @io.puts <<-EOS
        mol delrep top top
        mol representation NewCartoon
        mol color Structure
        mol addrep top
        EOS
    end

    private def seccode(sec : Protein::SecondaryStructure) : Char
      case sec
      when .helix_alpha? then 'H'
      when .helix3_10?   then 'G'
      when .helix_pi?    then 'I'
      when .helix_gamma? then 'B'
      when .polyproline? then 'T'
      when .beta_strand? then 'E'
      else                    'C'
      end
    end

    private def seccolor(sec : Protein::SecondaryStructure) : Array(Float64)
      sec.color.to_a.map &./(255).round(3)
    end

    private def seccolorid(sec : Protein::SecondaryStructure) : Int32
      case sec
      when .helix_alpha? then 29 # red2
      when .helix3_10?   then 13 # mauve
      when .helix_pi?    then 11 # purple
      when .helix_gamma? then 32 # orange3
      when .polyproline? then 17 # yellow2
      when .beta_strand? then 20 # green3
      else                    6  # silver
      end
    end
  end
end
