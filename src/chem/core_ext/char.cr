struct Char
  def presence
    self unless ascii_whitespace?
  end
end
