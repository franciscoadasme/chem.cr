require "./xyz/*"

module Chem::XYZ
  def self.build(**options) : String
    String.build do |io|
      build(io, **options) do |xyz|
        yield xyz
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
