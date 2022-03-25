class Chem::ResidueType::SyntaxParser
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
    @atom_type_map.last_value? || parse_exception(msg)
  end

  private def consume_element : String
    symbol = String.build do |io|
      io << @reader.current_char if @reader.current_char.ascii_uppercase?
      if (char = peek_char) && char.ascii_lowercase?
        io << char
        next_char
      end
    end
    parse_exception("Expected element") if symbol.empty?
    symbol
  end

  private def consume_int : Int32
    consume_while(&.ascii_number?).to_i
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
    advance_char = true
    loop do
      case char = @reader.current_char
      when .ascii_letter?
        atom_type = read_atom_type
        # TODO: Remove this hack: use * to denote cycles
        # TODO: check for duplicates in read_atom_type
        @atom_type_map[atom_type.name] ||= atom_type
        if bond_atom
          if bond_atom == atom_type
            parse_exception("Atom #{atom_type.name} cannot be bonded to itself")
          end
          bond_key = {String, String}.from [bond_atom.name, atom_type.name].sort!
          if bond_type = @bond_type_map[bond_key]?
            if bond_type.order != bond_order
              parse_exception("Bond #{bond_type} already exists")
            end
          else
            @bond_type_map[bond_key] = BondType.new(bond_atom, atom_type, bond_order)
          end
          bond_atom = nil
        end
      when '-'
        parse_exception("Unterminated bond") unless peek_char
        bond_atom ||= check_pred("Bond must be preceded by an atom")
        bond_order = 1
      when '='
        parse_exception("Unterminated bond") unless peek_char
        bond_atom ||= check_pred("Bond must be preceded by an atom")
        bond_order = 2
      when '#'
        parse_exception("Unterminated bond") unless peek_char
        bond_atom ||= check_pred("Bond must be preceded by an atom")
        bond_order = 3
      when '('
        if char = peek_char
          parse_exception("Expected bond at the beginning of a branch") unless char.in?("-=#")
        else # end of string
          parse_exception("Unclosed branch")
        end
        root_stack << (bond_atom || check_pred("Branch must be preceded by an atom"))
      when ')'
        bond_atom = root_stack.pop? || parse_exception("Invalid branch termination")
        if char = peek_char
          parse_exception("Expected bond after a branch") unless char.in?("-=#(")
        end
      when '{' # alias like "{backbone}"
        name = consume_while &.ascii_lowercase?
        parse_exception("Expected alias") if name.empty?
        spec = @aliases[name]? || parse_exception("Unknown alias #{name}")
        parse_exception("Unclosed alias") unless next_char == '}'
        raw_value = String.build do |io|
          io << @reader.string[0, @reader.pos - name.size - 1] \
            << spec \
            << @reader.string[(@reader.pos + 1)..]
        end
        @reader = Char::Reader.new(raw_value, @reader.pos - name.size - 1)
        advance_char = false # reader already consumes first char on creation
      when .nil?
        break
      else
        parse_exception("Invalid character #{char.inspect}")
      end

      if advance_char
        break unless next_char
      else
        advance_char = true
      end
    end
    parse_exception("Unclosed branch") unless root_stack.empty?
  end

  # Rename to fail
  private def parse_exception(msg)
    raise ParseException.new(msg)
  end

  private def peek_char : Char?
    if @reader.has_next?
      char = @reader.peek_next_char
      char if char != '\0'
    end
  end

  private def read_atom_type : AtomType
    atom_name = String.build do |io|
      consume_while io, &.ascii_uppercase?
      consume_while io, &.ascii_number?
    end
    parse_exception("Expected atom name") if atom_name.empty?
    atom_type = @atom_type_map[atom_name]?

    next_char

    element = nil
    formal_charge = 0
    valency = nil
    loop do
      case char = @reader.current_char
      when '+'
        formal_charge = peek_char.try(&.ascii_number?) ? consume_int : 1
      when '-'
        case peek_char
        when .nil?, '-' # minus charge (end of str or --, which is equal to -1-)
          parse_exception("Cannot modify charge of #{atom_name}") if atom_type
          formal_charge = -1
        when .ascii_number? # minus charge as -2, -3, etc.
          parse_exception("Cannot modify charge of #{atom_name}") if atom_type
          formal_charge = consume_int * -1
        else # single bond
          @reader.previous_char
          break
        end
      when '['
        parse_exception("Cannot modify element of #{atom_name}") if atom_type
        next_char
        element = consume_element
        case next_char
        when ']' # ok
        when .nil?
          parse_exception("Unclosed bracket")
        when .ascii_uppercase?
          parse_exception("Invalid element")
        else
          parse_exception("Unclosed bracket")
        end
      when '(' # explicit valency
        parse_exception("Cannot modify valency of #{atom_name}") if atom_type
        if peek_char.try(&.ascii_number?) # valency
          next_char
          valency = consume_int
          parse_exception("Unclosed bracket") unless next_char == ')'
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

    atom_type || AtomType.new(atom_name, formal_charge, element, valency)
  end
end
