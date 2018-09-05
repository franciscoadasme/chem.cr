require "../../configuration"

module Chem::VASP::Incar
  class PullParser
    include IO::PullParser

    alias Config = Chem::Configuration

    def parse : Config
      Config.new self
    end

    def read_parameter? : NamedTuple(name: String, value: Config::ValueType)?
      skip_whitespace
      if peek_char == '#' # it's a comment
        skip_line
        read_parameter?
      else
        name = scan(/[[:alpha:]]/).downcase
        skip /[= ]/
        value = parse_raw_value scan_until(/[\n#]/).strip
        {name: name, value: value}
      end
    rescue IO::EOFError
      nil
    end

    private def parse_raw_value(raw_value : String) : Config::ValueType
      case raw_value.strip(".").downcase
      when "true"
        true
      when "false"
        false
      else
        raw_value.to_i? || raw_value.to_f? || raw_value
      end
    end

    private def parse_exception(msg : String)
      raise ParseException.new msg
    end
  end
end
