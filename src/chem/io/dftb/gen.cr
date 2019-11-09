require "./gen/*"

module Chem::DFTB::Gen
  def self.build(**options) : String
    String.build do |io|
      build(io, **options) do |gen|
        yield gen
      end
    end
  end

  def self.build(io : ::IO, **options) : Nil
    builder = Builder.new io, **options
    builder.document do
      yield builder
    end
  end
end
