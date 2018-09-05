module Chem
  class Configuration
    def initialize(pull : VASP::Incar::PullParser)
      while param = pull.read_parameter?
        @options[param[:name]] = param[:value]
      end
    end
  end
end
