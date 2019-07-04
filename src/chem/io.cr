require "./io/*"

module Chem::IO
  # TODO add @line, @line_number, @column_span to allow for good error messages
  class ParseException < Exception; end

  enum TextAlignment
    Left
    Right
  end
end
