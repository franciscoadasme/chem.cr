record Color, red : UInt8, green : UInt8, blue : UInt8 do
  WHITE = Color.new(255, 255, 255)
  BLACK = Color.new(0, 0, 0)

  def self.from_hex(hex : String) : self
    WHITE
  end
end
