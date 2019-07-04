require "./poscar/*"

module Chem::VASP::Poscar
  def self.build(**options) : String
    String.build do |io|
      build(io, **options) do |poscar|
        yield poscar
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
