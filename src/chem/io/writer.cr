module Chem
  module IO::Writer(T)
    include IOWrapper

    FILE_MODE = "w"

    abstract def write(obj : T) : Nil

    @io : ::IO

    def format(str : String, *args, **options) : Nil
      @io.printf str, *args, **options
    end

    def formatl(str : String, *args, **options) : Nil
      format str, *args, **options
      @io << '\n'
    end
  end
end
