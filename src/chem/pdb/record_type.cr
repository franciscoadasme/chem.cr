module Chem::PDB
  enum RecordType
    Atom
    Citation
    End
    Experiment
    Header
    Lattice
    Remark
    Sequence
    Title
    Unknown

    def self.parse(string) : self
      parse?(string) || Unknown
    end

    def self.parse?(string) : self?
      {% begin %}
        {% mapping = {
             atom:       ["atom", "hetatm"],
             citation:   "jrnl",
             experiment: "expdta",
             lattice:    "cryst1",
             sequence:   "seqres",
           } %}
        case string.camelcase.downcase
        {% for member in @type.constants %}
          {% if member.symbolize != :Unknown %}
            {% name = member.stringify.camelcase.underscore %}
            {% if mapping[name].is_a?(StringLiteral) %}
                {% name = mapping[name] %}
            {% elsif mapping[name].is_a?(ArrayLiteral) %}
                {% name = mapping[name].splat %}
            {% end %}
            when {{name}}
              {{@type}}::{{member}}
          {% end %}
        {% end %}
        else
          nil
        end
      {% end %}
    end
  end
end
