module Chem::PDB::Hybrid36
  extend self

  def decode(str : String) : Int32?
    decode str, str.size
  end

  def decode(str : String, width : Int) : Int32
    decode?(str, width) || invalid_literal str
  end

  def decode?(str : String) : Int32?
    decode? str, str.size
  end

  def decode?(str : String, width : Int) : Int32?
    return unless str.size == width
    return 0 if str.blank?

    chr = str[0]
    return str.to_i? if chr == '-' || chr == ' ' || chr.ascii_number?
    return unless num = str.to_i?(base: 36)

    case chr
    when .ascii_uppercase?
      num - 10*36**(width - 1) + 10**width
    when .ascii_lowercase?
      num + 16*36**(width - 1) + 10**width
    end
  end

  def encode(num : Int, width : Int) : String
    String.build do |io|
      encode io, num, width
    end
  end

  def encode(io : ::IO, num : Int, width : Int) : Nil
    out_of_range num if num < 1 - 10**(width - 1)
    return io.printf "%#{width}d", num if num < 10**width
    num -= 10**width
    return (num + 10*36**(width - 1)).to_s 36, io, upcase: true if num < 26*36**(width - 1)
    num -= 26*36**(width - 1)
    return (num + 10*36**(width - 1)).to_s 36, io if num < 26*36**(width - 1)
    out_of_range num
  end

  private def invalid_literal(str : String)
    raise ArgumentError.new "Invalid number literal: #{str}"
  end

  private def out_of_range(num : Int)
    raise ArgumentError.new "Value out of range"
  end
end
