class String
  # Case equality. Delegates to `Chem::Atom#matches?`.
  def ===(atom : Chem::Atom) : Bool
    atom.matches?(self)
  end

  # Case equality. Delegates to `Chem::Residue#matches?`.
  def ===(residue : Chem::Residue) : Bool
    residue.matches?(self)

  def unescape : self
    gsub(/\\./) do |str|
      case str[1]
      when '\\' then '\\'
      when '"'  then '"'
      when 't'  then '\t'
      when 'r'  then '\r'
      when 'n'  then '\n'
      else           str[1]
      end
    end
  end
end
