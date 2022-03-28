class Chem::ResidueType::Parser
  # TODO: add custom error classes

  ALIASES = {"backbone" => "N(-H)-CA(-HA)(-C=O)"}

  def initialize(str, aliases : Hash(String, String)? = nil)
    @reader = Char::Reader.new(str.strip)
    @atom_type_map = {} of String => AtomType
    @bond_type_map = {} of Tuple(String, String) => BondType
    @aliases = {} of String => String
    @aliases.merge! ALIASES
    @aliases.merge! aliases if aliases
  end

  def atom_types : Array(AtomType)
    @atom_type_map.values
  end

  def bond_types : Array(BondType)
    @bond_type_map.values
  end

  private def check_pred(msg : String) : AtomType
    @atom_type_map.last_value? || raise(msg)
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

  private def add_bond(atom_type : AtomType, other : AtomType, order : Int32) : Nil
    raise "Atom #{atom_type.name} cannot be bonded to itself" if atom_type == other
    bond_key = {String, String}.from [atom_type.name, other.name].sort!
    if bond_type = @bond_type_map[bond_key]?
      if bond_type.order != order
        raise "Bond #{bond_type} already exists"
      end
    else
      @bond_type_map[bond_key] = BondType.new(atom_type, other, order)
    end
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
    root_stack = Deque(AtomType).new
    label_map = {} of Int32 => AtomType
    advance_char = true
    loop do
      case char = @reader.current_char
      when .ascii_letter?
        atom_type = read_atom_type
        @atom_type_map[atom_type.name] = atom_type
        if bond_atom
          add_bond bond_atom, atom_type, bond_order
          bond_atom = nil
        end
      when '-'
        raise "Unterminated bond" unless peek_char
        bond_atom ||= check_pred("Bond must be preceded by an atom")
        bond_order = 1
      when '='
        raise "Unterminated bond" unless peek_char
        bond_atom ||= check_pred("Bond must be preceded by an atom")
        bond_order = 2
      when '#'
        raise "Unterminated bond" unless peek_char
        bond_atom ||= check_pred("Bond must be preceded by an atom")
        bond_order = 3
      when '('
        if char = peek_char
          raise "Expected bond at the beginning of a branch" unless char.in?("-=#")
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
          atom_type = label_map[label_id]? || raise "Unknown label %#{label_id}"
          add_bond atom_type, bond_atom, bond_order
          bond_atom = nil
          label_map.delete label_id
        else # label previous atom
          raise "Duplicate label %#{label_id}" if label_map.has_key?(label_id)
          label_map[label_id] = check_pred("Label %#{label_id} must be preceded by an atom")
        end
      when .nil?
        break
      else
        raise "Invalid character #{char.inspect}"
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

  private def read_atom_type : AtomType
    atom_name = String.build do |io|
      consume_while io, &.ascii_uppercase?
      consume_while io, &.ascii_number?
    end
    raise "Expected atom name" if atom_name.empty?
    raise "Duplicate atom type #{atom_name}" if @atom_type_map.has_key?(atom_name)

    next_char

    element = nil
    formal_charge = 0
    valency = nil
    loop do
      case char = @reader.current_char
      when '+'
        formal_charge = peek_char.try(&.ascii_number?) ? read_int : 1
      when '-'
        case peek_char
        when .nil?, '-' # minus charge (end of str or --, which is equal to -1-)
          formal_charge = -1
        when .ascii_number? # minus charge as -2, -3, etc.
          formal_charge = read_int * -1
        else # single bond
          @reader.previous_char
          break
        end
      when '['
        next_char
        element = read_element
        case next_char
        when ']' # ok
        when .nil?
          raise "Unclosed bracket"
        when .ascii_uppercase?
          raise "Invalid element"
        else
          raise "Unclosed bracket"
        end
      when '('
        # TODO: drop explicit valency
        if peek_char.try(&.ascii_number?) # valency
          next_char
          valency = read_int
          raise "Unclosed bracket" unless next_char == ')'
        else
          @reader.previous_char
          break
        end
      else
        @reader.previous_char
        break
      end
      break unless next_char
    end

    element ||= PeriodicTable[atom_name: atom_name]
    AtomType.new(atom_name, element, formal_charge, valency)
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
