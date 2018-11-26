module Chem::PDB
  class Record::Iterator
    include ::Iterator(Record)

    @initial_pos : Int32
    @line_number = 0
    @prev_pos = -1
    @record = uninitialized Record

    def initialize(@io : ::IO)
      @initial_pos = @io.pos.to_i
    end

    def back : self
      @io.seek @prev_pos
      @line_number -= 1
      self
    end

    def each : Nil
      while true
        value = self.next
        break if value.is_a?(Stop)
        result = yield value
        break if result.is_a?(Stop)
      end
      back
    end

    def next
      @prev_pos = @io.pos.to_i
      if line = @io.gets
        @line_number += 1
        @record = Record.new line, @line_number
      else
        ::Iterator.stop
      end
    end

    def rewind
      @io.pos = @initial_pos
    end

    def skip(*names : String)
      loop do
        value = self.next
        return if value.is_a?(Stop)
        break unless names.includes? value.name
      end
      back
    end
  end
end
