class Chem::ResidueType::Parser
  ALIASES = {"backbone" => "N(-H)-CA(-HA)(-C=O)"}

  record AtomRecord, name : String,
    element : Element?,
    formal_charge : Int32,
    explicit_hydrogens : Int32?
  record BondRecord, lhs : String, rhs : String, order : Int32

  def initialize(str, aliases : Hash(String, String)? = nil)
    @reader = Char::Reader.new(str.strip)
    @atom_map = {} of String => AtomRecord
    @bond_map = {} of Tuple(String, String) => BondRecord
    @implicit_bonds = [] of BondRecord
    @aliases = {} of String => String
    @aliases.merge! ALIASES
    @aliases.merge! aliases if aliases
  end

  private def add_bond(atom : AtomRecord, other : AtomRecord, order : Int32) : Nil
    raise "Atom #{atom.name} cannot be bonded to itself" if atom == other
    bond_key = {String, String}.from [atom.name, other.name].sort!
    if @bond_map[bond_key]?
      raise "A bond between #{atom.name} and #{other.name} already exists"
    else
      @bond_map[bond_key] = BondRecord.new(atom.name, other.name, order)
    end
  end

  def atoms : Array(AtomRecord)
    @atom_map.values
  end

  def atom_map : Hash(String, AtomRecord)
    @atom_map
  end

  def bonds : Array(BondRecord)
    @bond_map.values
  end

  private def check_bond_succ
    case char = peek_char
    when .nil?, ')', '-', '=', '#'
      raise "Unmatched bond"
    when '('
      raise "Branching bond must be inside the branch"
    end
  end

  private def check_pred(msg : String) : AtomRecord
    @atom_map.last_value? || raise(msg)
  end

  private def consume_while(io : IO, & : Char -> Bool) : Nil
    if (yield @reader.current_char)
      io << @reader.current_char
    end
    while (char = peek_char) && (yield char)
      io << char
      next_char
    end
  end

  private def consume_while(& : Char -> Bool) : String
    String.build do |io|
      consume_while(io) do |char|
        yield char
      end
    end
  end

  private def current_char : Char
    @reader.current_char
  end

  private def current_char? : Char?
    char = @reader.current_char
    char if char != '\0'
  end

  def implicit_bonds : Array(BondRecord)
    @implicit_bonds
  end

  private def next_char : Char?
    if @reader.has_next?
      char = @reader.next_char
      char if char != '\0'
    end
  end

  def parse : Nil
    bond_atom = nil
    bond_order = 1
    root_stack = Deque(AtomRecord).new
    label_map = {} of Int32 => AtomRecord
    advance_char = true
    loop do
      case char = current_char
      when '[', .ascii_letter?
        raise "Expected bond between atoms" unless @atom_map.empty? || bond_atom
        atom = read_atom_record
        @atom_map[atom.name] = atom
        if bond_atom
          add_bond bond_atom, atom, bond_order
          bond_atom = nil
        end
      when '-'
        check_bond_succ
        bond_atom ||= check_pred("Bond must be preceded by an atom")
        bond_order = 1
      when '='
        check_bond_succ
        bond_atom ||= check_pred("Bond must be preceded by an atom")
        bond_order = 2
      when '#'
        check_bond_succ
        bond_atom ||= check_pred("Bond must be preceded by an atom")
        bond_order = 3
      when '('
        if char = peek_char
          unless char.in?("-=#")
            raise "Expected a bond at the beginning of a branch, got #{char.inspect}"
          end
        else # end of string
          raise "Unclosed branch"
        end
        root_stack << (bond_atom || check_pred("Branch must be preceded by an atom"))
      when ')'
        bond_atom = root_stack.pop? || raise "Invalid branch termination"
        if char = peek_char
          raise "Expected bond after a branch" unless char.in?("-=#(")
        end
      when '{' # alias like "{backbone}"
        name = consume_while &.ascii_lowercase?
        raise "Expected alias" if name.empty?
        spec = @aliases[name]? || raise "Unknown alias #{name}"
        raise "Unclosed alias" unless next_char == '}'
        raw_value = String.build do |io|
          io << @reader.string[0, @reader.pos - name.size - 1] \
            << spec \
            << @reader.string[(@reader.pos + 1)..]
        end
        @reader = Char::Reader.new(raw_value, @reader.pos - name.size - 1)
        advance_char = false # reader already consumes first char on creation
      when '%'
        next_char
        label_id = read_int
        if bond_atom # after a bond so add bond
          atom = label_map[label_id]? || raise "Unknown label %#{label_id}"
          add_bond atom, bond_atom, bond_order
          bond_atom = nil
          label_map.delete label_id
        else # label previous atom
          raise "Duplicate label %#{label_id}" if label_map.has_key?(label_id)
          label_map[label_id] = check_pred("Label %#{label_id} must be preceded by an atom")
        end
      when '*'
        raise "Implicit atom '*' must be preceded by a bond" unless bond_atom
        unless peek_char.in?(nil, ')')
          raise "Implicit bonds must be at the end of a branch or string"
        end
        @implicit_bonds << BondRecord.new(bond_atom.name, "*", bond_order)
        bond_atom = nil
      when '\0'
        break
      else
        raise "Invalid character #{char.inspect} in #{@reader.string}"
      end

      if advance_char
        break unless next_char
      else
        advance_char = true
      end
    end
    raise "Unclosed branch" unless root_stack.empty?
    raise "Unclosed label %#{label_map.first_key}" unless label_map.empty?
  end

  private def peek_char : Char?
    if @reader.has_next?
      char = @reader.peek_next_char
      char if char != '\0'
    end
  end

  private def raise(msg)
    ::raise ParseException.new(msg)
  end

  private def read_atom_record : AtomRecord
    bracketed = @reader.current_char == '['
    next_char if bracketed

    atom_name = String.build do |io|
      consume_while io, &.ascii_uppercase?
      consume_while io, &.ascii_number?
    end
    raise "Expected atom name" if atom_name.empty?

    # Disambiguate cases like [NH4+], where H4 is probably the number of
    # explicit hydrogens instead of an atom named NH4
    if bracketed && peek_char != 'H' && atom_name =~ /H\d+$/
      atom_name, _, num = atom_name.rpartition('H')
      (num.size + 1).times { @reader.previous_char }
    end

    raise "Duplicate atom #{atom_name}" if @atom_map.has_key?(atom_name)
    next_char

    element = nil
    formal_charge = 0
    explicit_hydrogens = nil
    if bracketed
      if current_char == '|'
        next_char
        element = read_element
        next_char
      end

      explicit_hydrogens = 0
      if current_char == 'H'
        next_char
        if current_char.ascii_number?
          explicit_hydrogens = read_int
          if explicit_hydrogens <= 0
            raise "Invalid number of hydrogens (#{explicit_hydrogens}) for #{atom_name}"
          end
          next_char
        else
          explicit_hydrogens = 1
        end
      end

      if (symbol = current_char).in?('+', '-')
        sign = symbol == '+' ? 1 : -1
        case next_char
        when Nil
          # end of string
        when symbol
          loop do
            formal_charge += 1 * sign
            break unless next_char == symbol
          end
        when .ascii_number?
          formal_charge = read_int * sign
          next_char
        else
          formal_charge = sign
        end
      end

      raise "Unmatched bracket" if current_char != ']'
    else
      @reader.previous_char
    end

    AtomRecord.new(atom_name, element, formal_charge, explicit_hydrogens)
  end

  private def read_element : Element
    symbol = String.build do |io|
      io << @reader.current_char if @reader.current_char.ascii_uppercase?
      if (char = peek_char) && char.ascii_lowercase?
        io << char
        next_char
      end
    end
    raise "Expected element" if symbol.empty?
    PeriodicTable[symbol]
  end

  private def read_int : Int32
    consume_while(&.ascii_number?).to_i
  end
end