require "colorize"

module Colorize
  struct ColorRGB
    def self.from_hex(hex : String) : self
      hex = hex.lchop '#'
      new hex[0..1].to_u8(16), hex[2..3].to_u8(16), hex[4..5].to_u8(16)
    end

    def to_a : Array(UInt8)
      [@red, @green, @blue]
    end
  end
end
