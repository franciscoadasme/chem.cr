# NOTE: Standard atom weights (in Da) are taken from Meija  J.  et al.  Pure Appl.
# Chem.  2016  88 (3)  pp 265-291
# doi:[10.1515/pac-2015-0305](https://dx.doi.org/10.1515/pac-2015-0305)
#
# NOTE: Covalent radii (in Å) are taken from Cordero  B.  et al.  Dalton Trans.  2008
# 21  pp 2832-2838  doi:[10.1039/b801115j](https://dx.doi.org/10.1039/b801115j). Missing
# values are set to 1.5 Å
#
# NOTE: vdW radii (in Å) are taken from Alvarez  S.  Dalton Trans.  2013  42  pp
# 8617-8636  doi:[10.1039/c3dt50599e](https://dx.doi.org/10.1039/c3dt50599e). Missing
# values are set to covalent radius + 0.9 Å
#
# Maximum number of bonds are taken from OpenBabel.
module Chem::PeriodicTable
  extend self

  {% begin %}
    {% data = <<-DATA
        #                           mass    Rcov    Rvdw  Nele  valence  MaxBnd
        1  H   Hydrogen           1.0079    0.31    1.20     1        1       1
        2  He  Helium             4.0026    0.20    1.43     2        0       0
        3  Li  Lithium            6.941     1.28    2.12     1        1       1
        4  Be  Beryllium          9.0122    0.96    1.98     2        2       2
        5  B   Boron             10.811     0.84    1.91     3        3       4
        6  C   Carbon            12.0107    0.76    1.77     4        4       4
        7  N   Nitrogen          14.0067    0.71    1.66     5        3       4
        8  O   Oxygen            15.9994    0.66    1.50     6        2       2
        9  F   Fluorine          18.9984    0.57    1.46     7        1       1
       10  Ne  Neon              20.1797    0.50    1.58     8        0       0
       11  Na  Sodium            22.9898    1.66    2.50     1        1       1
       12  Mg  Magnesium         24.305     1.41    2.51     2        2       2
       13  Al  Aluminum          26.9815    1.21    2.25     3      3,6       6
       14  Si  Silicon           28.0855    1.11    2.19     4      4,6       6
       15  P   Phosphorus        30.9738    1.07    1.90     5      3,5       6
       16  S   Sulfur            32.065     1.05    1.89     6    2,4,6       6
       17  Cl  Chlorine          35.453     1.02    1.82     7        1       1
       18  Ar  Argon             39.948     1.06    1.83     8        0       0
       19  K   Potassium         39.0983    2.03    2.73     1        1       1
       20  Ca  Calcium           40.078     1.76    2.62     2        2       2
       21  Sc  Scandium          44.9559    1.70    2.58     3        _       6
       22  Ti  Titanium          47.867     1.60    2.46     4        _       6
       23  V   Vanadium          50.9415    1.53    2.42     5        _       6
       24  Cr  Chromium          51.9961    1.39    2.45     6        _       6
       25  Mn  Manganese         54.938     1.61    2.45     7        _       8
       26  Fe  Iron              55.845     1.52    2.44     8        _       6
       27  Co  Cobalt            58.9331    1.50    2.40     9        _       6
       28  Ni  Nickel            58.6934    1.24    2.40    10        _       6
       29  Cu  Copper            63.546     1.32    2.38    11        _       6
       30  Zn  Zinc              65.409     1.22    2.39     2        _       6
       31  Ga  Gallium           69.723     1.22    2.32     3        3       3
       32  Ge  Germanium         72.64      1.20    2.29     4        4       4
       33  As  Arsenic           74.9216    1.19    1.88     5    3,5,7       3
       34  Se  Selenium          78.96      1.20    1.82     6    2,4,6       2
       35  Br  Bromine           79.904     1.20    1.86     7        1       1
       36  Kr  Krypton           83.798     1.16    2.25     8        0       0
       37  Rb  Rubidium          85.4678    2.20    3.21     1        1       1
       38  Sr  Strontium         87.62      1.95    2.84     2        2       2
       39  Y   Yttrium           88.9059    1.90    2.75     3        _       6
       40  Zr  Zirconium         91.224     1.75    2.52     4        _       6
       41  Nb  Niobium           92.9064    1.64    2.56     5        _       6
       42  Mo  Molybdenum        95.94      1.54    2.45     6        _       6
       43  Tc  Technetium        98.0       1.47    2.44     7        _       6
       44  Ru  Ruthenium        101.07      1.46    2.46     8        _       6
       45  Rh  Rhodium          102.9055    1.42    2.44     9        _       6
       46  Pd  Palladium        106.42      1.39    2.15    10        _       6
       47  Ag  Silver           107.8682    1.45    2.53    11        _       6
       48  Cd  Cadmium          112.411     1.44    2.49     2        _       6
       49  In  Indium           114.818     1.42    2.43     3        3       3
       50  Sn  Tin              118.71      1.39    2.42     4      2,4       4
       51  Sb  Antimony         121.76      1.39    2.47     5    3,5,7       3
       52  Te  Tellurium        127.6       1.38    1.99     6    2,4,6       2
       53  I   Iodine           126.9045    1.39    2.04     7    1,3,5       1
       54  Xe  Xenon            131.293     1.40    2.06     8  0,2,4,6       0
       55  Cs  Cesium           132.9055    2.44    3.48     1        1       1
       56  Ba  Barium           137.327     2.15    3.03     2        2       2
       57  La  Lanthanum        138.9055    2.07    2.98     3        _       2
       58  Ce  Cerium           140.116     2.04    2.88     4        _       6
       59  Pr  Praseodymium     140.9077    2.03    2.92     3        _       6
       60  Nd  Neodymium        144.242     2.01    2.95     4        _       6
       61  Pm  Promethium       145.0       1.90       _     5        _       6
       62  Sm  Samarium         150.36      1.98    2.90     6        _       6
       63  Eu  Europium         151.964     1.98    2.87     7        _       6
       64  Gd  Gadolinium       157.25      1.96    2.83     8        _       6
       65  Tb  Terbium          158.9254    1.94    2.79     9        _       6
       66  Dy  Dysprosium       162.5       1.92    2.87    10        _       6
       67  Ho  Holmium          164.9303    1.92    2.81    11        _       6
       68  Er  Erbium           167.259     1.89    2.83    12        _       6
       69  Tm  Thulium          168.9342    1.90    2.79    13        _       6
       70  Yb  Ytterbium        173.04      1.87    2.80    14        _       6
       71  Lu  Lutetium         174.967     1.87    2.74    15        _       6
       72  Hf  Hafnium          178.49      1.75    2.63     4        _       6
       73  Ta  Tantalum         180.9479    1.70    2.53     5        _       6
       74  W   Tungsten         183.84      1.62    2.57     6        _       6
       75  Re  Rhenium          186.207     1.51    2.49     7        _       6
       76  Os  Osmium           190.23      1.44    2.48     8        _       6
       77  Ir  Iridium          192.217     1.41    2.41     9        _       6
       78  Pt  Platinum         195.084     1.36    2.29    10        _       6
       79  Au  Gold             196.9666    1.36    2.32    11        _       6
       80  Hg  Mercury          200.59      1.32    2.45     2        _       6
       81  Tl  Thallium         204.3833    1.45    2.47     3        3       3
       82  Pb  Lead             207.2       1.46    2.60     4      2,4       4
       83  Bi  Bismuth          208.9804    1.48    2.54     5    3,5,7       3
       84  Po  Polonium         209.0       1.40       _     6    2,4,6       2
       85  At  Astatine         210.0       1.50       _     7    1,3,5       1
       86  Rn  Radon            222.0       1.50       _     8        0       0
       87  Fr  Francium         223.0       2.60       _     1        1       1
       88  Ra  Radium           226.0       2.21       _     2        2       2
       89  Ac  Actinium         227.0       2.15    2.80     3        _       6
       90  Th  Thorium          232.0381    2.06    2.93     4        _       6
       91  Pa  Proactinium      231.0359    2.00    2.88     3        _       6
       92  U   Uranium          238.0289    1.96    2.71     4        _       6
       93  Np  Neptunium        237.0       1.90    2.82     5        _       6
       94  Pu  Plutonium        244.0       1.87    2.81     6        _       6
       95  Am  Americium        243.0       1.80    2.83     7        _       6
       96  Cm  Curium           247.0       1.69    3.05     8        _       6
       97  Bk  Berkelium        247.0          _    3.40     9        _       6
       98  Cf  Californium      251.0          _    3.05    10        _       6
       99  Es  Einsteinium      252.0          _    2.70    11        _       6
      100  Fm  Fermium          257.0          _       _    12        _       6
      101  Md  Mendelevium      258.0          _       _    13        _       6
      102  No  Nobelium         259.0          _       _    14        _       6
      103  Lr  Lawrencium       262.0          _       _    15        _       6
      104  Rf  Rutherfordium    261.0          _       _     2        _       6
      105  Db  Dubnium          262.0          _       _     2        _       6
      106  Sg  Seaborgium       266.0          _       _     2        _       6
      107  Bh  Bohrium          264.0          _       _     2        _       6
      108  Hs  Hassium          277.0          _       _     2        _       6
      109  Mt  Meitnerium       268.0          _       _     2        _       6
      110  Ds  Darmstadtium     281.0          _       _     2        _       6
      111  Rg  Roentgenium      272.0          _       _     2        _       6
      112  Cn  Copernicium      285.0          _       _     2        _       6
      113  Nh  Nihonium         284.0          _       _     2        _       6
      114  Fl  Flerovium        289.0          _       _     2        _       6
      115  Mc  Moscovium        288.0          _       _     2        _       6
      116  Lv  Livermorium      292.0          _       _     2        _       6
      117  Ts  Tennessine       291.0          _       _     2        _       6
      118  Og  Oganesson        294.0          _       _     2        _       6
      DATA
    %}

    {% for line in data.lines[1..] %}
      {% num, symbol, name, mass, rcov, rvdw, nelec, valence, maxbnd = line.split %}
      {% rcov = 1.5 if rcov == "_" %}
      {% valence = valence == "_" ? nil : valence.split(",").map(&.id) %}
      {% valence = valence[0] if valence && valence.size == 1 %}
      {{symbol.id}} = Element.new(
        atomic_number: {{num.id}},
        symbol: {{symbol}},
        name: {{name}},
        mass: {{mass.id}},
        covalent_radius: {{rcov.id}},
        vdw_radius: {{rvdw.id == "_" ? "#{rcov.id} + 0.9".id : rvdw.id}},
        valence_electrons: {{nelec.id}},
        valence: {{valence}},
        max_bonds: {{maxbnd.id}},
      )
    {% end %}
  {% end %}

  def [](*args, **options) : Element
    self[*args, **options]? || unknown_element *args, **options
  end

  def []?(number : Int32) : Element?
    {% begin %}
      case number
      {% for name, i in @type.constants.select { |c| @type.constant(c).is_a?(Call) } %}
        {% if i < 118 %}
          when {{i + 1}}
            {{@type}}::{{name}}
        {% end %}
      {% end %}
      end
    {% end %}
  end

  def []?(symbol : String | Char) : Element?
    {% begin %}
      case symbol.to_s.capitalize
      {% for name, i in @type.constants.select { |c| @type.constant(c).is_a?(Call) } %}
        {% if i < 118 %}
          when {{name.stringify}}
            {{@type}}::{{name}}
        {% end %}
      {% end %}
      end
    {% end %}
  end

  def []?(*, name : String) : Element?
    {% begin %}
      case name
      {% for name, i in @type.constants.select { |c| @type.constant(c).is_a?(Call) } %}
        {% if i < 118 %}
          when {{@type}}::{{name}}.name
            {{@type}}::{{name}}
        {% end %}
      {% end %}
      end
    {% end %}
  end

  # TODO: delete this! it's only used in building connectivity
  def covalent_cutoff(atom : Atom, other : Atom) : Float64
    covalent_cutoff atom.element, other.element
  end

  # NOTE: The additional term (0.3 Å) is taken from the covalent radii reference,
  # which states that about 96% of the surveyed bonds are within three standard
  # deviations of the sum of the radii, where the found average standard deviation is
  # about 0.1 Å.
  def covalent_cutoff(ele : Element, other : Element) : Float64
    covalent_pair_dist_table[{ele, other}] ||= \
       (ele.covalent_radius + other.covalent_radius + 0.3) ** 2
  end

  def covalent_distance(ele : Element, other : Element) : Float64
    # The additional term (0.3 Å) is taken from the covalent radii
    # reference, which states that about 96% of the surveyed bonds are
    # within three standard deviations of the sum of the radii, where
    # the found average standard deviation is about 0.1 Å.
    ele.covalent_radius + other.covalent_radius + 0.3
  end

  def elements : Tuple
    {% begin %}
      {
        {% for name, i in @type.constants.select { |c| @type.constant(c).is_a?(Call) } %}
          {% if i < 118 %}
            {{@type}}::{{name}},
          {% end %}
        {% end %}
      }
    {% end %}
  end

  private def covalent_pair_dist_table : Hash(Tuple(Element, Element), Float64)
    @@covalent_pair_dist_table ||= {} of Tuple(Element, Element) => Float64
  end

  private def unknown_element(*args, **options)
    value = options.values.first? || args[0]?
    raise Error.new "Unknown element: #{value}"
  end
end
