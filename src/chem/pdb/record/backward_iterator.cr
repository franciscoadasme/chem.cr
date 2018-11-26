module Chem::PDB
  class Record::BackwardIterator
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
      @line_number += 1
      self
    end

    def each : Nil
      while true
        value = self.next
        break if value.is_a?(Stop)
        result = yield value
        break if result.is_a?(Stop)
      end
    end

    def next
      return ::Iterator.stop if @io.pos == 0
      @prev_pos = @io.pos.to_i
      line = String.build do |io|
        loop do
          @io.pos -= 2
          break unless (chr = @io.read_char) && chr != '\n'
          io << chr
          break if @io.pos == 0
        end
      end.reverse
      @line_number -= 1
      @record = Record.new line, @line_number
    end

    def rewind
      @io.pos = @initial_pos
    end
  end
end
