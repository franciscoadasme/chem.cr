module Chem
  module FormatWriter(T)
    include IO::Wrapper

    # File open mode. May be overriden by including types.
    FILE_MODE = "w"

    abstract def write(obj : T) : Nil

    def format(str : String, *args, **options) : Nil
      @io.printf str, *args, **options
    end

    def formatl(str : String, *args, **options) : Nil
      format str, *args, **options
      @io << '\n'
    end
  end
end
