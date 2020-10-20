struct UInt8
  def ascii_number? : Bool
    48 <= self <= 57
  end

  def ascii_sign? : Bool
    self == 43 || self == 45
  end

  def ascii_whitespace? : Bool
    self == 32 || 9 <= self <= 13
  end
end
