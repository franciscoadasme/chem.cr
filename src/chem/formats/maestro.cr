require "compress/gzip"

# This module provides support for reading and writing Schrödinger
# Maestro files (`.mae`, `.maegz`, `.mae.gz`).
#
# The layout follows [maeparser][maeparser]: a file is a token stream of
# nested blocks, and each structure is an `f_m_ct` block. Atoms and
# bonds live in indexed `m_atom[N]` / `m_bond[N]` blocks with 1-based
# indexes. Bond rows are stored in one direction; files that list both
# directions are accepted and de-duplicated.
#
# Multi-entry files are read with `.each` / `.read_all` and written as
# successive `f_m_ct` blocks. Path overloads decompress or compress
# `.maegz` and `.mae.gz`. `Chem.read("file.mae.gz")` selects this format
# because extensions are matched as a filename suffix.
#
# `<>` is undefined: it is omitted from metadata and does not overwrite
# typed field defaults. Title and CRYST1 stay on `Structure#title` and
# `#cell`, not metadata. Extra columns are stored as metadata; on write,
# keys that are not already Maestro property names are emitted as
# `{b|i|r|s}_user_<name>`.
#
# Atom names prefer `s_m_pdb_atom_name`, then `s_m_atom_name`. Residue
# atoms without a name use `{element}{index}`. Bonds of order 4 are
# Kekulized on read. Formal charges and bonds come from the file.
#
# WARNING: Basic support only. Stereo, display, and other advanced
# blocks are stored as metadata or skipped.
#
# [maeparser]: https://github.com/schrodinger/maeparser
@[Chem::RegisterFormat(ext: %w(.mae .maegz .mae.gz))]
module Chem::Maestro
  BLOCK_BEGINNING     = '{'
  PROPERTY_NAME_REGEX = /^[birs]_[a-zA-Z0-9]+_.+$/
  BLOCK_END           = '}'
  DELIMITER           = ":::"
  EMPTY_FIELD         = "<>"

  # Yields each structure in *io*.
  def self.each(io : IO, source_file : Path | String | Nil = nil, & : Structure ->) : Nil
    source_file ||= (file = io).is_a?(File) ? file.path : nil
    pull = PullParser.new(io)
    loop do
      begin
        yield read(pull, source_file)
      rescue IO::EOFError
        break
      end
    end
  end

  # Yields each structure in *path*.
  # Compressed `.maegz` and `.mae.gz` files are decompressed.
  def self.each(path : Path | String, & : Structure ->) : Nil
    open(path) do |io|
      each(io, path) do |struc|
        yield struc
      end
    end
  end

  # Returns the next structure from *io*.
  # Use `read_all` or `each` for multiple.
  def self.read(io : IO, source_file : Path | String | Nil = nil) : Structure
    source_file ||= (file = io).is_a?(File) ? file.path : nil
    read PullParser.new(io), source_file
  end

  # Returns the first structure in *path*.
  # Compressed `.maegz` and `.mae.gz` files are decompressed.
  def self.read(path : Path | String) : Structure
    open(path) do |io|
      read(io, path)
    end
  end

  # Returns all structures in *io*.
  def self.read_all(io : IO, source_file : Path | String | Nil = nil) : Array(Structure)
    ary = [] of Structure
    each(io, source_file) { |struc| ary << struc }
    ary
  end

  # Returns all structures in *path*.
  # Compressed `.maegz` and `.mae.gz` files are decompressed.
  def self.read_all(path : Path | String) : Array(Structure)
    open(path) { |io| read_all(io, path) }
  end

  # Writes *struc* to *io*.
  def self.write(io : IO, struc : Structure) : Nil
    write_version(io)
    write_ct(io, struc)
  end

  # Writes each structure in *entries* to *io* as successive `f_m_ct` blocks.
  def self.write(io : IO, entries : Enumerable(Structure)) : Nil
    write_version(io)
    entries.each_with_index do |struc, i|
      io.puts unless i == 0
      write_ct(io, struc)
    end
  end

  # Writes *struc* to *path*.
  # Compressed `.maegz` and `.mae.gz` files are gzip-compressed.
  def self.write(path : Path | String, struc : Structure) : Nil
    open(path, write: true) { |io| write(io, struc) }
  end

  # Writes each structure in *entries* to *path*.
  # Compressed `.maegz` and `.mae.gz` files are gzip-compressed.
  def self.write(path : Path | String, entries : Enumerable(Structure)) : Nil
    open(path, write: true) { |io| write(io, entries) }
  end

  private def self.read(pull : PullParser, source_file : Path | String | Nil) : Structure
    skip_to_outer_block pull, "f_m_ct"
    parse_ct pull, source_file
  end

  private def self.open(path : Path | String, *, write : Bool = false, & : IO ->)
    path = Path[path]
    File.open(path, write ? "w" : "r") do |file|
      name = path.basename.downcase
      if name.ends_with?(".maegz") || name.ends_with?(".mae.gz")
        if write
          Compress::Gzip::Writer.open(file) { |gzip| yield gzip }
        else
          Compress::Gzip::Reader.open(file) { |gzip| yield gzip }
        end
      else
        yield file
      end
    end
  end

  private def self.parse_ct(pull : PullParser, source_file : Path | String | Nil) : Structure
    struc = Structure.new(source_file)

    a = b = c = alpha = beta = gamma = nil
    read_properties(pull).each do |name|
      value = read_value(pull, name)
      next if value.nil?
      case name
      when "s_m_title"
        struc.title = value if value.is_a?(String)
      when "r_pdb_PDB_CRYST1_a"
        a = value.as(Float64)
        pull.error("Invalid cell size a") unless a > 0
      when "r_pdb_PDB_CRYST1_b"
        b = value.as(Float64)
        pull.error("Invalid cell size b") unless b > 0
      when "r_pdb_PDB_CRYST1_c"
        c = value.as(Float64)
        pull.error("Invalid cell size c") unless c > 0
      when "r_pdb_PDB_CRYST1_alpha"
        alpha = value.as(Float64)
        pull.error("Invalid cell angle alpha") unless 0 < alpha <= 180
      when "r_pdb_PDB_CRYST1_beta"
        beta = value.as(Float64)
        pull.error("Invalid cell angle beta") unless 0 < beta <= 180
      when "r_pdb_PDB_CRYST1_gamma"
        gamma = value.as(Float64)
        pull.error("Invalid cell angle gamma") unless 0 < gamma <= 180
      else
        struc.metadata[name] = value
      end
    end

    if a && b && c && alpha && beta && gamma
      struc.cell = Spatial::Parallelepiped.new({a, b, c}, {alpha, beta, gamma})
    end

    aromatic = [] of Bond
    loop do
      skip_ws_and_comments(pull)
      break if consume_char?(pull, BLOCK_END)
      pull.error("Unclosed block") if pull.eof?
      name, size = read_block_header(pull)
      if n = size
        case name
        when "m_atom" then parse_atoms(pull, struc, n)
        when "m_bond" then parse_bonds(pull, struc, n, aromatic)
        else               skip_to_block_end(pull)
        end
      else
        skip_to_block_end(pull)
      end
    end
    Chem.kekulize(aromatic)
    struc
  end

  private def self.parse_atoms(pull : PullParser, struc : Structure, size : Int32) : Nil
    properties = read_properties(pull)
    pull.error("Missing i_m_atomic_number") unless properties.includes?("i_m_atomic_number")
    chain = nil
    residue = nil
    ele_index = Hash(Element, Int32).new(default_value: 0)
    size.times do
      x = y = z = partial_charge = 0.0
      occupancy = 1.0
      temperature_factor = 0.0
      formal_charge = 0
      number = nil.as(Int32?)
      chid = resnum = name = resname = inscode = nil
      ele = nil.as(Element?)
      metadata = Metadata.new

      skip_ws_and_comments(pull)
      pull.next_i # atom id (1-based file order)
      properties.each do |prop|
        case prop
        when "r_m_x_coord"          then read_float(pull).try { |v| x = v }
        when "r_m_y_coord"          then read_float(pull).try { |v| y = v }
        when "r_m_z_coord"          then read_float(pull).try { |v| z = v }
        when "s_m_pdb_atom_name"    then name = read_string(pull)
        when "i_m_residue_number"   then resnum = read_int(pull)
        when "s_m_pdb_residue_name" then resname = read_string(pull)
        when "s_m_insertion_code"   then inscode = read_string(pull).try(&.[0]?)
        when "s_m_chain_name"       then chid = read_string(pull).try { |s| s[0] if s[0].alphanumeric? }
        when "i_m_formal_charge"    then read_int(pull).try { |v| formal_charge = v }
        when "r_m_charge1"          then read_float(pull).try { |v| partial_charge = v }
        when "r_m_pdb_occupancy"    then read_float(pull).try { |v| occupancy = v }
        when "r_m_pdb_tfactor"      then read_float(pull).try { |v| temperature_factor = v }
        when "i_pdb_PDB_serial"     then number = read_int(pull)
        when "s_m_atom_name"        then read_string(pull).try { |str| name ||= str }
        when "i_m_atomic_number"
          ele = read_int(pull).try { |z| PeriodicTable[z]? } ||
                pull.error("Invalid atomic number %{token}")
        else
          read_value(pull, prop).try { |value| metadata[prop] = value }
        end
      end
      ele = ele.not_nil!

      if ch = chid
        chain = struc.dig?(ch) || Chain.new(struc, ch)
      end
      if i = resnum
        chain ||= Chain.new(struc, Chain.succ_id)
        unless residue.try { |res| res.number == i && res.insertion_code == inscode }
          ele_index.clear
        end
        residue = chain.dig?(i, inscode) ||
                  Residue.new(chain, i, inscode, resname || residue.try(&.name) || "UNK")
      elsif resname && residue.try(&.name) != resname
        chain ||= Chain.new(struc, Chain.succ_id)
        ele_index.clear
        resid_n = (chain.residues.max_of?(&.number) || 0) + 1
        residue = Residue.new(chain, resid_n, resname)
      end

      pos = Spatial::Vec3.new(x, y, z)
      atom = if residue
               atom_name = name || "#{ele.symbol}#{ele_index[ele] += 1}"
               Atom.new(residue, atom_name, pos,
                 element: ele,
                 number: number,
                 formal_charge: formal_charge,
                 occupancy: occupancy,
                 partial_charge: partial_charge,
                 temperature_factor: temperature_factor)
             else
               Atom.new(struc, ele, pos,
                 name: name,
                 number: number,
                 formal_charge: formal_charge,
                 occupancy: occupancy,
                 partial_charge: partial_charge,
                 temperature_factor: temperature_factor)
             end
      atom.metadata.merge! metadata
    end
    finish_indexed_block(pull)
  end

  private def self.parse_bonds(
    pull : PullParser,
    struc : Structure,
    size : Int32,
    aromatic : Array(Bond),
  ) : Nil
    properties = read_properties(pull)
    atoms = struc.atoms
    size.times do
      skip_ws_and_comments(pull)
      pull.next_i # bond id
      i = j = nil.as(Int32?)
      order = 1
      properties.each do |name|
        case name
        when "i_m_from"
          if i = read_int(pull)
            pull.error("Atom index #{i} out of range") unless 1 <= i <= atoms.size
          end
        when "i_m_to"
          if j = read_int(pull)
            pull.error("Atom index #{j} out of range") unless 1 <= j <= atoms.size
          end
        when "i_m_order"
          if v = read_int(pull)
            pull.error("Invalid bond order #{v}") unless v.in?(0..4)
            order = v
          end
        else
          read_value(pull, name)
        end
      end
      i || pull.error("Missing i_m_from")
      j || pull.error("Missing i_m_to")
      case order
      when 0, 1, 2, 3
        atoms[i - 1].bonds.add atoms[j - 1], BondOrder.from_value(order)
      when 4
        aromatic << atoms[i - 1].bonds.add(atoms[j - 1])
      end
    end
    finish_indexed_block(pull)
  end

  private def self.read_block_header(pull : PullParser) : {String, Int32?}
    skip_ws_and_comments(pull)
    pull.consume { |char| char.ascii_letter? || char.ascii_number? || char == '_' }
    name = pull.str? || pull.error("Expected block name")
    skip_ws_and_comments(pull)
    indexed = nil
    if consume_char?(pull, '[')
      skip_ws_and_comments(pull)
      pull.consume { |char| char == '-' || char.ascii_number? }
      indexed = pull.int
      skip_ws_and_comments(pull)
      pull.error("Bad block index; missing ']'") unless consume_char?(pull, ']')
      skip_ws_and_comments(pull)
    end
    pull.error("Missing '{' for block") unless consume_char?(pull, BLOCK_BEGINNING)
    {name, indexed}
  end

  private def self.finish_indexed_block(pull : PullParser) : Nil
    skip_ws_and_comments(pull)
    if pull.peek == ':'
      pull.consume_token
      pull.error("Expected ':::'") unless pull.str? == DELIMITER
      skip_ws_and_comments(pull)
    end
    pull.error("Missing closing '}' for indexed block") unless consume_char?(pull, BLOCK_END)
  end

  private def self.next_outer_block(pull : PullParser) : String?
    skip_ws_and_comments(pull)
    return if pull.eof?
    if consume_char?(pull, BLOCK_BEGINNING)
      ""
    else
      name, indexed = read_block_header(pull)
      pull.error("Outer block cannot be indexed") if indexed
      name
    end
  end

  private def self.skip_to_outer_block(pull : PullParser, name : String) : Nil
    loop do
      found = next_outer_block(pull)
      raise IO::EOFError.new unless found
      return if found == name
      skip_to_block_end(pull)
    end
  end

  private def self.read_properties(pull : PullParser) : Array(String)
    Array(String).new.tap do |properties|
      loop do
        skip_ws_and_comments(pull)
        pull.error("Missing property key") if pull.eof?
        if pull.peek == ':'
          pull.consume_token
          pull.error("Bad ':::' token") unless pull.str? == DELIMITER
          break
        end
        pull.consume_token
        name = (pull.str? || pull.error("Missing property key")).delete('\\')
        if name.matches?(PROPERTY_NAME_REGEX)
          properties << name
        else
          pull.error("Invalid property '%{token}'. " \
                     "Must follow format '(b|i|r|s)_<author>_<name>'")
        end
      end
    end
  end

  private def self.read_value(pull : PullParser, name : String) : Bool | Int32 | Float64 | String | Nil
    case name[0]
    when 'b' then read_bool(pull)
    when 'i' then read_int(pull)
    when 'r' then read_float(pull)
    when 's' then read_string(pull)
    else          raise "BUG: unreachable"
    end
  end

  private def self.read_bool(pull : PullParser) : Bool?
    skip_ws_and_comments(pull)
    pull.consume_token
    case pull.str?
    when EMPTY_FIELD then nil
    when "0"         then false
    when "1"         then true
    else                  pull.error("Invalid boolean")
    end
  end

  private def self.read_float(pull : PullParser) : Float64?
    skip_ws_and_comments(pull)
    pull.consume_token
    return if pull.token == EMPTY_FIELD.to_slice
    pull.float
  end

  private def self.read_int(pull : PullParser) : Int32?
    skip_ws_and_comments(pull)
    pull.consume_token
    return if pull.token == EMPTY_FIELD.to_slice
    pull.int
  end

  private def self.read_string(pull : PullParser) : String?
    skip_ws_and_comments(pull)
    if pull.peek == '"'
      quote_count = 2
      escaped = false
      pull.consume do |char|
        should_consume_char = quote_count > 0
        case char
        when '\\'
          escaped = true
        when '"'
          quote_count -= 1 unless escaped
          escaped = false
        else
          escaped = false
        end
        should_consume_char
      end
      pull.str.strip('"').strip.unescape.presence
    else
      value = pull.next_s
      value.strip.presence unless value == EMPTY_FIELD
    end
  end

  private def self.skip_to_block_end(pull : PullParser) : Nil
    depth = 1
    until depth == 0
      skip_ws_and_comments(pull)
      pull.error("Unclosed block") if pull.eof?
      if consume_char?(pull, BLOCK_BEGINNING)
        depth += 1
      elsif consume_char?(pull, BLOCK_END)
        depth -= 1
      elsif pull.peek == '"'
        read_string(pull)
      else
        pull.consume_token
        pull.error("Unclosed block") unless pull.str?
      end
    end
  end

  private def self.skip_ws_and_comments(pull : PullParser) : Nil
    loop do
      return if pull.eof?
      pull.skip_whitespace
      case pull.peek
      when nil
        pull.consume_line
      when '#'
        skip_comment(pull)
      else
        return
      end
    end
  end

  private def self.skip_comment(pull : PullParser) : Nil
    pull.consume(1)
    loop do
      pull.consume { |char| char != '#' }
      if pull.peek == '#'
        pull.consume(1)
        return
      end
      pull.consume_line
      pull.error("Unterminated comment") if pull.line.nil?
    end
  end

  private def self.consume_char?(pull : PullParser, char : Char) : Bool
    return false unless pull.peek == char
    pull.consume(1)
    true
  end

  private def self.write_version(io : IO) : Nil
    io.puts <<-EOS
    {
      s_m_m2io_version
      :::
      2.0.0
    }
    EOS
  end

  private def self.write_ct(io : IO, struc : Structure) : Nil
    io.puts "f_m_ct {"
    write_header(io, struc)
    write_atoms(io, struc)
    write_bonds(io, struc)
    io.puts "}"
  end

  private def self.write_atoms(io : IO, struc : Structure) : Nil
    atoms = struc.atoms
    return if atoms.empty?
    columns = atom_columns(struc)
    io.puts "  m_atom[#{atoms.size}] {"
    columns.each { |name| io.puts "    #{name}" }
    io.puts "    :::"
    atoms.each_with_index do |atom, i|
      extra = {} of String => Metadata::Any
      atom.metadata.each do |key, any|
        next if any.as_a?
        extra[property_name(key, any)] = any
      end
      io << "    " << (i + 1)
      columns.each do |name|
        io << ' '
        write_token(io, atom_value(atom, name) || extra[name]?)
      end
      io.puts
    end
    io.puts "    :::"
    io.puts "  }"
  end

  private def self.write_bonds(io : IO, struc : Structure) : Nil
    bonds = struc.bonds
    return if bonds.empty?
    index = struc.atoms.each.with_index(offset: 1).to_h
    io.puts "  m_bond[#{bonds.size}] {"
    io.puts "    i_m_from"
    io.puts "    i_m_to"
    io.puts "    i_m_order"
    io.puts "    :::"
    bonds.each_with_index do |bond, i|
      a, b = bond.atoms
      io.puts "    #{i + 1} #{index[a]} #{index[b]} #{bond.order.to_i}"
    end
    io.puts "    :::"
    io.puts "  }"
  end

  private def self.write_header(io : IO, struc : Structure) : Nil
    names = %w(s_m_title)
    values = [struc.title.presence] of Bool | Int32 | Float64 | String | Nil | Metadata::Any
    if cell = struc.cell?
      a, b, c = cell.size
      alpha, beta, gamma = cell.angles
      names.concat %w(
        r_pdb_PDB_CRYST1_a r_pdb_PDB_CRYST1_b r_pdb_PDB_CRYST1_c
        r_pdb_PDB_CRYST1_alpha r_pdb_PDB_CRYST1_beta r_pdb_PDB_CRYST1_gamma
      )
      values << a.to_f << b.to_f << c.to_f << alpha.to_f << beta.to_f << gamma.to_f
    end
    struc.metadata.each do |key, any|
      next if any.as_a?
      name = property_name(key, any)
      next if name.in?(names)
      names << name
      values << any
    end
    names.each { |name| io.puts "  #{name}" }
    io.puts "  :::"
    values.each do |value|
      io << "  "
      write_token(io, value)
      io.puts
    end
  end

  private def self.atom_columns(struc : Structure) : Array(String)
    columns = %w(
      i_m_atomic_number r_m_x_coord r_m_y_coord r_m_z_coord
      i_m_formal_charge r_m_charge1 s_m_pdb_atom_name
      r_m_pdb_occupancy r_m_pdb_tfactor i_pdb_PDB_serial
    )
    if struc.has_topology?
      columns.concat %w(
        i_m_residue_number s_m_pdb_residue_name s_m_insertion_code s_m_chain_name
      )
    end
    seen = columns.to_set
    struc.atoms.each do |atom|
      atom.metadata.each do |key, any|
        next if any.as_a?
        name = property_name(key, any)
        next if name.in?(seen)
        seen << name
        columns << name
      end
    end
    columns
  end

  private def self.atom_value(atom : Atom, name : String) : Bool | Int32 | Float64 | String | Nil
    case name
    when "i_m_atomic_number"    then atom.atomic_number
    when "r_m_x_coord"          then atom.x
    when "r_m_y_coord"          then atom.y
    when "r_m_z_coord"          then atom.z
    when "i_m_formal_charge"    then atom.formal_charge
    when "r_m_charge1"          then atom.partial_charge
    when "r_m_pdb_occupancy"    then atom.occupancy
    when "r_m_pdb_tfactor"      then atom.temperature_factor
    when "i_pdb_PDB_serial"     then atom.number
    when "s_m_pdb_atom_name"    then atom.name?
    when "i_m_residue_number"   then atom.residue?.try(&.number)
    when "s_m_pdb_residue_name" then atom.residue?.try(&.name)
    when "s_m_insertion_code"   then atom.residue?.try(&.insertion_code).try(&.to_s)
    when "s_m_chain_name"       then atom.chain?.try(&.id.to_s)
    end
  end

  private def self.property_name(key : String, any : Metadata::Any) : String
    return key if key.matches?(PROPERTY_NAME_REGEX)
    type = case any.raw
           when Bool  then 'b'
           when Int   then 'i'
           when Float then 'r'
           else            's'
           end
    "#{type}_user_#{key}"
  end

  private def self.write_string(io : IO, value : String) : Nil
    if value.empty?
      io << %("")
      return
    end
    quote = value == EMPTY_FIELD || value.each_char.any? do |char|
      char.whitespace? || char.in?('"', '\\', '{', '}', '#', '[', ']', ':')
    end
    unless quote
      io << value
      return
    end
    io << '"'
    value.each_char do |char|
      io << '\\' if char.in?('"', '\\')
      io << char
    end
    io << '"'
  end

  private def self.write_token(io : IO, value : Bool | Int32 | Float64 | String | Nil | Metadata::Any) : Nil
    case value
    when Metadata::Any then write_token(io, value.raw.as(Bool | Int32 | Float64 | String))
    when Nil           then io << EMPTY_FIELD
    when Bool          then io << (value ? '1' : '0')
    when String        then write_string(io, value)
    else                    io << value
    end
  end
end
