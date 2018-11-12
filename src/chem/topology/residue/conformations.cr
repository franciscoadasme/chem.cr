require "../../core_ext/number"

module Chem
  class Residue
    class Conformation
      getter id : Char
      getter occupancy : Float64
      protected getter atoms = [] of Atom

      protected def initialize(@id : Char, @occupancy : Float64)
      end
    end

    class ConformationManager
      include Enumerable(Conformation)

      @conformations = [] of Conformation
      @current_conf : Conformation?
      @residue : Residue

      delegate each, to: @conformations

      def initialize(@residue : Residue)
      end

      def [](id : Char) : Conformation
        self[id]? || raise Error.new "#{@residue} does not have conformation #{id}"
      end

      def []?(id : Char) : Conformation?
        find &.id.==(id)
      end

      private def add(id : Char, occupancy : Float64) : Conformation
        if total_occupancy + occupancy > 1
          raise Error.new "Sum of occupancies in #{@residue} will be greater than 1 " \
                          "when adding conformation #{id}"
        end

        @conformations << (conf = Conformation.new id, occupancy)
        @current_conf ||= conf
        conf
      end

      def any?
        !@conformations.empty?
      end

      def current : Conformation?
        @current_conf
      end

      def current=(id : Char)
        self.current = self[id] unless current.try(&.id) == id
      end

      private def current=(conf : Conformation)
        @residue.swap_conf_atoms conf.atoms
        @current_conf = conf
      end

      def next
        return unless any?
        next_idx = @conformations.index!(@current_conf) + 1
        next_idx = 0 if next_idx >= @conformations.size
        self.current = @conformations[next_idx]
      end

      private def total_occupancy : Float64
        @conformations.sum &.occupancy
      end
    end
  end
end
