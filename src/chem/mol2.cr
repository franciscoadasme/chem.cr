require "./mol2/*"

module Chem::Mol2
  def self.build(**options) : String
    String.build do |io|
      build(io, **options) do |mol2|
        yield mol2
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
