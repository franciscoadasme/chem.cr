module Chem
  abstract class FormatWriter(T)
    abstract def write(obj : T) : Nil

    property? sync_close = false
    getter? closed = false

    @io : ::IO

    def initialize(input : ::IO | Path | String, *, @sync_close : Bool = false)
      if input.is_a?(Path | String)
        input = File.new(input, "w")
        @sync_close = true
      end
      @io = input
    end

    def self.open(io : ::IO | Path | String, *args, sync_close : Bool = false, **options)
      writer = new io, *args, **options, sync_close: sync_close
      yield writer ensure writer.close
    end

    def close : Nil
      return if @closed
      @io.flush
      @closed = true
      @io.close if @sync_close
    end

    def format(str : String, *args, **options) : Nil
      @io.printf str, *args, **options
    end

    def formatl(str : String, *args, **options) : Nil
      format str, *args, **options
      @io << '\n'
    end

    protected def check_open
      raise Error.new "Closed IO" if closed?
    end
  end
end
