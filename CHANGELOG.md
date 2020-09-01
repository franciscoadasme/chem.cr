# 0.4.0 (2020-08-22)

This small release mainly focuses on manipulating secondary structure and introduces a novel algorithm termed QUESSO.

## Core

- Added iteration over secondary structure elements
- **(breaking change)** Renamed `Residue#secondary_structure` to `#sec`
- Added residue chirality methods
- `Residue#previous` and `#next` now falls back to sequence order if link bond is missing

## Input/output

- Handled error on missing remark id in PDB
- Don't skip to end after reading POSCAR
- PDB output now includes secondary structure information

## Spatial measurement and transformation

- Added improper angle calculation
- Matrix can be now loaded from a file

## Topology

- **(breaking change)** Refactored secondary structure enum members to include handedness
- **(breaking change)** Renamed `SecondaryStructure#dssp` to `#code`
- Added secondary structure type
- Added secondary structure information like minimum size
- Refactored secondary structure equality (handedness and type)
- **(breaking change)** Helix 2_7 renamed to gamma
- Added chirality to DSSP
- Added QUESSO secondary structure assignment method

# 0.3.0

This release introduces some big changes to code hierarchy and topology perception, and new features like support for volumetric data.

## Core

* **(breaking change)** Renamed `Experiment::Kind` enum to `Method`
* **(breaking change)** Moved valency-related methods to Atom
* Residue kind is now updated after changing name
* Structures can now be cloned
* Added methods to get bonded residues (#60, #66)
* `Residue#previous` and `#next` are now computed properties (#70)
* Atom mass and vdW radius are now mutable (#72)

## Input/output

* **(breaking change)** Dropped builder pattern in favor of more simple writers
* Fixed not flushing an IO before closing it
* Added writer formatting helper methods
* Added specialized fast ASCII parser
* Added DX file format support
* **(breaking change)** Dropped string content as parser argument
* File format can now be specified when reading/writing
* Added CHGCAR/LOCPOT file format support
* Added Gaussian's Cube file format support (#35)
* Guess file format from filename (#37, #53)
* Fixed misalignment for four-letter residue names in PDB (#51)
* Atom order is now preserved in POSCAR output (#52)

## Topology

* **(breaking change)** Merged `Structure::Builder` and `Topology::Builder`
* **(breaking change)** Renamed `Templates::Residue` to `ResidueType`
* **(breaking change)** Enforce chain id to be alphanumeric
* **(breaking change)** Merged topology assignment from templates into `Structure::Builder`
* **(breaking change)** Refactored topology perception into a class (#68)
* Bonds are now guessed for all atoms
* Topology perception is now enabled by default
* Avoid stack overflow in fragment detection for large structures
* Residues for unidentified atoms are now guessed from connectivity
* Rename unidentified atoms (#29)
* Guess bonds of unidentified atoms (#55)
* Pre-calculate maximum covalent distance to speed up bond search (#57)
* Fixed not setting residue types for unknown residues (#69)

## Spatial measurements and transformations

* **(breaking change)** Renamed `Vector#resize(by)` to `#pad`
* **(breaking change)** Renamed `Size3D` to `Size` and related methods
* Added `Spatial::Grid` for volumetric data
* **(breaking change)** Parsers and writers are now generic
* Added origin to lattice
* Added volume calculation
* Re-added basic basis impl.
* Added vector PBC image methods
* Fixed PBC image for atom outside primary unit cell (#56)
* Added `*_with_distance` methods to KDTree
* Added bounds
* Auto-enable PBC support in KDTree
* Added coordinates centering methods (#30)
* Measurements are now PBC-aware (#71)

## Miscellaneous

* **(breaking change)** Refactored code folder structure
* Added benchmarks

# 0.2.0

This release introduces some big changes to topology handling and file formats.

## Core

* Collections now can tell their size
* Views now share collection functionality
* Added dig methods

## Input/output

* **(breaking change)** Refactored IO classes to use annotations for associating parsers and writers to file formats, which allows for automatic method definition for reading and writing via macros
* Added specialized parser mixins (e.g., text parser, column-based parser, ASCII parser)
* Added DFTB+'s Gen file format support
* Added Mol2 file format support
* Added XYZ file format support
* Added PDB output
* Element order can now be set in POSCAR output
* Added chain/conformation/het options for PDB reading
* **(breaking change)** Removed residue alternate conformations
* Added support for hybrid36 numbering
* **(breaking change)** Dropped coordinate system from POSCAR
* Added location tracking to some parsers
* **(breaking change)** Refactored parsers to act as iterators
* Parsers now use `Structure::Builder`
* PDB parsing was simplified while avoiding edge cases

## Topology

* Added atom formal and partial charge
* Added multiple valencies and ionic elements
* Added bond detection and topology perception from geometry
* Added support for root atoms and terminal groups in residue template detection
* Fixed not allowing three-letter atom names
* Added mutating methods
* Added residue renumbering by connectivity
* Added STRIDE (external) support for secondary structure assignment

## Spatial measurement and transformation

* **(breaking change)** Added `Spatial::CoordinatesProxy` to centralize coordinates manipulation/transformation
* Added PBC unwrapping
* **(breaking change)** Removed basis-related code
* **(breaking change)** Removed inverse transformation caching
* Added PBC-related methods to Vector (e.g., `#to_fractional`, `#wrap`)
* Optimized pbc wrap for non-cuboid lattices
* **(breaking change)** Dropped scale factor and space group from lattice

# 0.1.0

Initial version of chem.cr

## Features

* Hierarchical access to structure topology
* Basic topology perception via templates 
* Support for standard file formats like PDB
* Spatial measurements and transformations
