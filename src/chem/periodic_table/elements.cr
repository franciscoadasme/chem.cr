require "./macros"

# NOTE: Standard atom weights (in Da) are taken from Meija, J., et al., Pure Appl.
# Chem., 2016, 88 (3), pp 265-291,
# doi:[10.1515/pac-2015-0305](https://dx.doi.org/10.1515/pac-2015-0305)
#
# NOTE: Covalent radii (in Å) are taken from Cordero, B., et al., Dalton Trans., 2008,
# 21, pp 2832-2838, doi:[10.1039/b801115j](https://dx.doi.org/10.1039/b801115j). Missing
# values are set to 1.5 Å
#
# NOTE: vdW radii (in Å) are taken from Alvarez, S., Dalton Trans., 2013, 42, pp
# 8617-8636, doi:[10.1039/c3dt50599e](https://dx.doi.org/10.1039/c3dt50599e). Missing
# values are set to covalent radius + 0.9 Å
module Chem::PeriodicTable
  element H, Hydrogen,
    covalent_radius: 0.31,
    mass: 1.0079,
    valence: 1,
    vdw_radius: 1.2
  element He, Helium,
    covalent_radius: 0.2,
    mass: 4.0026,
    valence: 0,
    vdw_radius: 1.43
  element Li, Lithium,
    covalent_radius: 1.28,
    mass: 6.941,
    vdw_radius: 2.12
  element Be, Beryllium,
    covalent_radius: 0.96,
    mass: 9.0122,
    vdw_radius: 1.98
  element B, Boron,
    covalent_radius: 0.84,
    mass: 10.811,
    vdw_radius: 1.91
  element C, Carbon,
    covalent_radius: 0.76,
    mass: 12.0107,
    valence: 4,
    vdw_radius: 1.77
  element N, Nitrogen,
    covalent_radius: 0.71,
    mass: 14.0067,
    valence: 3,
    vdw_radius: 1.66
  element O, Oxygen,
    covalent_radius: 0.66,
    mass: 15.9994,
    valence: 2,
    vdw_radius: 1.5
  element F, Fluorine,
    covalent_radius: 0.57,
    mass: 18.9984,
    valence: 1,
    vdw_radius: 1.46
  element Ne, Neon,
    covalent_radius: 0.5,
    mass: 20.1797,
    vdw_radius: 1.58
  element Na, Sodium,
    covalent_radius: 1.66,
    mass: 22.9898,
    valence: 1,
    vdw_radius: 2.5
  element Mg, Magnesium,
    covalent_radius: 1.41,
    mass: 24.305,
    vdw_radius: 2.51
  element Al, Aluminum,
    covalent_radius: 1.21,
    mass: 26.9815,
    vdw_radius: 2.25
  element Si, Silicon,
    covalent_radius: 1.11,
    mass: 28.0855,
    vdw_radius: 2.19
  element P, Phosphorus,
    covalent_radius: 1.07,
    mass: 30.9738,
    valence: 5,
    vdw_radius: 1.9
  element S, Sulfur,
    covalent_radius: 1.05,
    mass: 32.065,
    valence: 2,
    vdw_radius: 1.89
  element Cl, Chlorine,
    covalent_radius: 1.02,
    mass: 35.453,
    valence: 1,
    vdw_radius: 1.82
  element Ar, Argon,
    covalent_radius: 1.06,
    mass: 39.948,
    vdw_radius: 1.83
  element K, Potassium,
    covalent_radius: 2.03,
    mass: 39.0983,
    valence: 1,
    vdw_radius: 2.73
  element Ca, Calcium,
    covalent_radius: 1.76,
    mass: 40.078,
    valence: 1,
    vdw_radius: 2.62
  element Sc, Scandium,
    covalent_radius: 1.70,
    mass: 44.9559,
    vdw_radius: 2.58
  element Ti, Titanium,
    covalent_radius: 1.60,
    mass: 47.867,
    vdw_radius: 2.46
  element V, Vanadium,
    covalent_radius: 1.53,
    mass: 50.9415,
    vdw_radius: 2.42
  element Cr, Chromium,
    covalent_radius: 1.39,
    mass: 51.9961,
    vdw_radius: 2.45
  element Mn, Manganese,
    covalent_radius: 1.61,
    mass: 54.938,
    vdw_radius: 2.45
  element Fe, Iron,
    covalent_radius: 1.52,
    mass: 55.845,
    vdw_radius: 2.44
  element Co, Cobalt,
    covalent_radius: 1.50,
    mass: 58.9331,
    vdw_radius: 2.4
  element Ni, Nickel,
    covalent_radius: 1.24,
    mass: 58.6934,
    vdw_radius: 2.4
  element Cu, Copper,
    covalent_radius: 1.32,
    mass: 63.546,
    vdw_radius: 2.38
  element Zn, Zinc,
    covalent_radius: 1.22,
    mass: 65.409,
    vdw_radius: 2.39
  element Ga, Gallium,
    covalent_radius: 1.22,
    mass: 69.723,
    vdw_radius: 2.32
  element Ge, Germanium,
    covalent_radius: 1.20,
    mass: 72.64,
    vdw_radius: 2.29
  element As, Arsenic,
    covalent_radius: 1.19,
    mass: 74.9216,
    vdw_radius: 1.88
  element Se, Selenium,
    covalent_radius: 1.20,
    mass: 78.96,
    vdw_radius: 1.82
  element Br, Bromine,
    covalent_radius: 1.20,
    mass: 79.904,
    valence: 1,
    vdw_radius: 1.86
  element Kr, Krypton,
    covalent_radius: 1.16,
    mass: 83.798,
    vdw_radius: 2.25
  element Rb, Rubidium,
    covalent_radius: 2.20,
    mass: 85.4678,
    vdw_radius: 3.21
  element Sr, Strontium,
    covalent_radius: 1.95,
    mass: 87.62,
    vdw_radius: 2.84
  element Y, Yttrium,
    covalent_radius: 1.90,
    mass: 88.9059,
    vdw_radius: 2.75
  element Zr, Zirconium,
    covalent_radius: 1.75,
    mass: 91.224,
    vdw_radius: 2.52
  element Nb, Niobium,
    covalent_radius: 1.64,
    mass: 92.9064,
    vdw_radius: 2.56
  element Mo, Molybdenum,
    covalent_radius: 1.54,
    mass: 95.94,
    vdw_radius: 2.45
  element Tc, Technetium,
    covalent_radius: 1.47,
    mass: 98,
    vdw_radius: 2.44
  element Ru, Ruthenium,
    covalent_radius: 1.46,
    mass: 101.07,
    vdw_radius: 2.46
  element Rh, Rhodium,
    covalent_radius: 1.42,
    mass: 102.9055,
    vdw_radius: 2.44
  element Pd, Palladium,
    covalent_radius: 1.39,
    mass: 106.42,
    vdw_radius: 2.15
  element Ag, Silver,
    covalent_radius: 1.45,
    mass: 107.8682,
    vdw_radius: 2.53
  element Cd, Cadmium,
    covalent_radius: 1.44,
    mass: 112.411,
    vdw_radius: 2.49
  element In, Indium,
    covalent_radius: 1.42,
    mass: 114.818,
    vdw_radius: 2.43
  element Sn, Tin,
    covalent_radius: 1.39,
    mass: 118.71,
    vdw_radius: 2.42
  element Sb, Antimony,
    covalent_radius: 1.39,
    mass: 121.76,
    vdw_radius: 2.47
  element Te, Tellurium,
    covalent_radius: 1.38,
    mass: 127.6,
    vdw_radius: 1.99
  element I, Iodine,
    covalent_radius: 1.39,
    mass: 126.9045,
    valence: 1,
    vdw_radius: 2.04
  element Xe, Xenon,
    covalent_radius: 1.40,
    mass: 131.293,
    vdw_radius: 2.06
  element Cs, Cesium,
    covalent_radius: 2.44,
    mass: 132.9055,
    vdw_radius: 3.48
  element Ba, Barium,
    covalent_radius: 2.15,
    mass: 137.327,
    vdw_radius: 3.03
  element La, Lanthanum,
    covalent_radius: 2.07,
    mass: 138.9055,
    vdw_radius: 2.98
  element Ce, Cerium,
    covalent_radius: 2.04,
    mass: 140.116,
    vdw_radius: 2.88
  element Pr, Praseodymium,
    covalent_radius: 2.03,
    mass: 140.9077,
    vdw_radius: 2.92
  element Nd, Neodymium,
    covalent_radius: 2.01,
    mass: 144.242,
    vdw_radius: 2.95
  element Pm, Promethium,
    covalent_radius: 1.9,
    mass: 145
  element Sm, Samarium,
    covalent_radius: 1.98,
    mass: 150.36,
    vdw_radius: 2.9
  element Eu, Europium,
    covalent_radius: 1.98,
    mass: 151.964,
    vdw_radius: 2.87
  element Gd, Gadolinium,
    covalent_radius: 1.96,
    mass: 157.25,
    vdw_radius: 2.83
  element Tb, Terbium,
    covalent_radius: 1.94,
    mass: 158.9254,
    vdw_radius: 2.79
  element Dy, Dysprosium,
    covalent_radius: 1.92,
    mass: 162.5,
    vdw_radius: 2.87
  element Ho, Holmium,
    covalent_radius: 1.92,
    mass: 164.9303,
    vdw_radius: 2.81
  element Er, Erbium,
    covalent_radius: 1.89,
    mass: 167.259,
    vdw_radius: 2.83
  element Tm, Thulium,
    covalent_radius: 1.90,
    mass: 168.9342,
    vdw_radius: 2.79
  element Yb, Ytterbium,
    covalent_radius: 1.87,
    mass: 173.04,
    vdw_radius: 2.8
  element Lu, Lutetium,
    covalent_radius: 1.87,
    mass: 174.967,
    vdw_radius: 2.74
  element Hf, Hafnium,
    covalent_radius: 1.75,
    mass: 178.49,
    vdw_radius: 2.63
  element Ta, Tantalum,
    covalent_radius: 1.70,
    mass: 180.9479,
    vdw_radius: 2.53
  element W, Tungsten,
    covalent_radius: 1.62,
    mass: 183.84,
    vdw_radius: 2.57
  element Re, Rhenium,
    covalent_radius: 1.51,
    mass: 186.207,
    vdw_radius: 2.49
  element Os, Osmium,
    covalent_radius: 1.44,
    mass: 190.23,
    vdw_radius: 2.48
  element Ir, Iridium,
    covalent_radius: 1.41,
    mass: 192.217,
    vdw_radius: 2.41
  element Pt, Platinum,
    covalent_radius: 1.36,
    mass: 195.084,
    vdw_radius: 2.29
  element Au, Gold,
    covalent_radius: 1.36,
    mass: 196.9666,
    vdw_radius: 2.32
  element Hg, Mercury,
    covalent_radius: 1.32,
    mass: 200.59,
    vdw_radius: 2.45
  element Tl, Thallium,
    covalent_radius: 1.45,
    mass: 204.3833,
    vdw_radius: 2.47
  element Pb, Lead,
    covalent_radius: 1.46,
    mass: 207.2,
    vdw_radius: 2.6
  element Bi, Bismuth,
    covalent_radius: 1.48,
    mass: 208.9804,
    vdw_radius: 2.54
  element Po, Polonium,
    covalent_radius: 1.40,
    mass: 209
  element At, Astatine,
    covalent_radius: 1.5,
    mass: 210
  element Rn, Radon,
    covalent_radius: 1.5,
    mass: 222
  element Fr, Francium,
    covalent_radius: 2.6,
    mass: 223
  element Ra, Radium,
    covalent_radius: 2.21,
    mass: 226
  element Ac, Actinium,
    covalent_radius: 2.15,
    mass: 227,
    vdw_radius: 2.8
  element Th, Thorium,
    covalent_radius: 2.06,
    mass: 232.0381,
    vdw_radius: 2.93
  element Pa, Proactinium,
    covalent_radius: 2.00,
    mass: 231.0359,
    vdw_radius: 2.88
  element U, Uranium,
    covalent_radius: 1.96,
    mass: 238.0289,
    vdw_radius: 2.71
  element Np, Neptunium,
    covalent_radius: 1.90,
    mass: 237,
    vdw_radius: 2.82
  element Pu, Plutonium,
    covalent_radius: 1.87,
    mass: 244,
    vdw_radius: 2.81
  element Am, Americium,
    covalent_radius: 1.80,
    mass: 243,
    vdw_radius: 2.83
  element Cm, Curium,
    covalent_radius: 1.69,
    mass: 247,
    vdw_radius: 3.05
  element Bk, Berkelium,
    mass: 247,
    vdw_radius: 3.4
  element Cf, Californium,
    mass: 251,
    vdw_radius: 3.05
  element Es, Einsteinium,
    mass: 252,
    vdw_radius: 2.7
  element Fm, Fermium,
    mass: 257
  element Md, Mendelevium,
    mass: 258
  element No, Nobelium,
    mass: 259
  element Lr, Lawrencium,
    mass: 262
  element Rf, Rutherfordium,
    mass: 261
  element Db, Dubnium,
    mass: 262
  element Sg, Seaborgium,
    mass: 266
  element Bh, Bohrium,
    mass: 264
  element Hs, Hassium,
    mass: 277
  element Mt, Meitnerium,
    mass: 268
  element Ds, Darmstadtium,
    mass: 281
  element Rg, Roentgenium,
    mass: 272
  element Cn, Copernicium,
    mass: 285
  element Uut, Ununtrium,
    mass: 284
  element Uuq, Ununquadium,
    mass: 289
  element Uup, Ununpentium,
    mass: 288
  element Uuh, Ununhexium,
    mass: 292
  element Uus, Ununseptium,
    mass: 291
  element Uuo, Ununoctium,
    mass: 294
end
