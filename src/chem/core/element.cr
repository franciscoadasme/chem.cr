class Chem::Element
  getter atomic_number : Int32
  getter covalent_radius : Float64
  getter mass : Float64
  getter max_bonds : Int32
  getter name : String
  getter symbol : String
  getter valence : Int32 | Array(Int32) | Nil
  getter valence_electrons : Int32
  getter vdw_radius : Float64

  protected def initialize(
    @atomic_number : Int32,
    @symbol : String,
    @name : String,
    @mass : Float64,
    @covalent_radius : Float64,
    @vdw_radius : Float64,
    @valence_electrons : Int32,
    @valence : Int32 | Array(Int32) | Nil,
    @max_bonds : Int32
  )
  end

  # TODO: delete this!
  def ionic? : Bool
    @symbol.in?("Na", "Mg", "K", "Ca")
  end

  def heavy? : Bool
    !hydrogen?
  end

  def inspect(io : IO) : Nil
    io << "<Element " << @symbol << '(' << @atomic_number << ")>"
  end

  def max_valence : Int32?
    case valence = @valence
    in Int32, Nil then valence
    in Array      then valence.last
    end
  end

  def valence : Int32?
    case valence = @valence
    in Int32, Nil then valence
    in Array      then valence.first
    end
  end

  def valence(effective_valence : Int32) : Int32
    case valence = @valence
    in Int32
      valence
    in Array
      valence.find(&.>=(effective_valence)) || valence.last
    in Nil
      effective_valence
    end
  end

  def valences : Array(Int32)
    case valence = @valence
    in Int32
      [valence]
    in Array
      valence
    in Nil
      [] of Int32
    end
  end

  macro finished
    {% for constant in PeriodicTable.constants %}
      {% call = PeriodicTable.constant(constant) %} # call to Element#new
      {% name = call.named_args[2].value %}
      {% method_name = (name.downcase + "?").id %}

      # Returns `true` if the element is {{name}}, else `false`.
      def {{method_name}}
        same? PeriodicTable::{{constant.id}}
      end
    {% end %}
  end
end
