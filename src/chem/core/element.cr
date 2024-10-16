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

  # Case equality. Delegates to `Atom#matches?`.
  def ===(atom : Atom) : Bool
    atom.matches?(self)
  end

  def heavy? : Bool
    !hydrogen?
  end

  def max_valence : Int32?
    case valence = @valence
    in Int32, Nil then valence
    in Array      then valence.last
    end
  end

  # Returns the total number of electrons in the valence shell.
  #
  # This method follows the octet rule (duet for hydrogen and helium),
  # accounting for the expanded octet in the cases of phosphorus,
  # sulfur, etc.
  def target_electrons(valence : Int32) : Int32
    case self
    when .hydrogen?, .helium?
      2
    when .phosphorus?, .arsenic?
      case valence
      when 0..4 then 8
      when 5    then 10
      else           12
      end
    when .sulfur?, .selenium?
      case valence
      when 0..3 then 8
      when 4    then 10
      else           12
      end
    else
      8 # octet for most organic elements
    end
  end

  # Returns the target valence given the effective valence. This is
  # useful for multi-valent elements (e.g., sulfur, phosphorus).
  def target_valence(effective_valence : Int) : Int32
    case valence = @valence
    in Int32
      valence
    in Array
      valence.find(&.>=(effective_valence)) || valence.last
    in Nil
      effective_valence
    end
  end

  def valence : Int32?
    case valence = @valence
    in Int32, Nil then valence
    in Array      then valence.first
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

  def to_s(io : IO) : Nil
    io << '<' << {{@type.name.split("::").last}} << ' ' << @symbol << '>'
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
