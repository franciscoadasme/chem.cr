struct Int
  def ascii_letter? : Bool
    ascii_lowercase? || ascii_uppercase?
  end

  def ascii_lowercase? : Bool
    97 <= self <= 122
  end

  def ascii_number? : Bool
    48 <= self <= 57
  end

  def ascii_sign? : Bool
    self == 43 || self == 45
  end

  def ascii_uppercase? : Bool
    65 <= self <= 90
  end

  def ascii_whitespace? : Bool
    self == 32 || 9 <= self <= 13
  end

  def ascii_word? : Bool
    ascii_letter? || ascii_number? || self == 45 || self == 95
  end
end
