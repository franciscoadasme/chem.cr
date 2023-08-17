# Changelog

## [v0.6.0] - 2023-08-09

Development got erratic after v0.5.0 and the tracking of releases was ignored for years.
This version includes a ton of changes done throughout 2021-2023, and it attempts to reset the release cycle.
It is expected that future releases will come periodically (a few months in between).

### Changed

#### Core

- **Breaking:** refactor the constructors of topology objects (chain, residue, atom) to accept the parent as the first argument
- **Breaking:** rename `valency` to `valence` in method names
- **Breaking:** rename the `Element#valence(Int)` method to `#target_valence`
- **Breaking:** rename the `Atom#match?` method to `#matches?`
- **Breaking:** rename the `Atom#nominal_valence` method to `#target_valence`
- **Breaking:** do not accept integer as bond order. Use `BondOrder` enum instead
- **Breaking:** remove `Residue#dssp` method. Use `residue.sec.code` instead
- **Breaking:** rename the `Residue#previous` and `#next` methods to `#pred` and `#succ`, respectively
- **Breaking:** refactor the `Residue#pred` and `#succ` methods to raise if nil
- **Breaking:** rename the `Residue::Kind` enum to `ResidueType`
- **Breaking:** rename the `#renumber_by_connectivity` method in `Structure` and `Chain` to `#renumber_residues_by_connectivity`
- **Breaking:** refactor `ArrayView`'s methods to return views, not raw arrays
- **Breaking:** refactor array views to a shard (https://github.com/franciscoadasme/views)

#### Topology

- **Breaking:** disable implicit bond detection and topology guessing (#175). Use the `guess_bonds` and `guess_names` arguments in readers and ` Structure::Builder` instead
- **Breaking:** move the `Topology::Perception#apply_templates ` method to the `Topology` type
- **Breaking:** move element guessing to the `Topology` namespace (#140)
- **Breaking:** move the `Topology::Templates` namespace to top level
- **Breaking:** move the `Topology::(Atom|Bond|Residue)Type` types to the `Templates` namespace without the `Type` suffix
- **Breaking:** set the `root` argument as required in the `Templates::Residue`'s constructor (#104)
- **Breaking:** set the `element` argument as required in the `Templates::Atom`'s constructor
- **Breaking:** move residue template methods and types to the `Templates` namespace
- **Breaking:** remove the methods for defining templates of specific type (e.g., `Templates.aminoacid`). Use the `Templates::Builder#type` method during construction instead
- **Breaking:** refactor `Templates::Detector`'s API
- **Breaking:** refactor `Templates::MatchData`'s API to use `Templates::Atom`
- **Breaking:** rename the `Templates::Builder#main` method to `#stem`
- **Breaking:** remove the `Templates::Builder#aliases` method. Use the `#name` method with multiple arguments during construction instead
- **Breaking:** remove the implicit hook to define the backbone atoms in templates. Use the `Templates::Builder#backbone` method instead
- **Breaking:** use implicit bonds (instead of explicit valence) to define inter-residue bonds in templates
- **Breaking:** rename `HlxParams`'s methods: `#zeta` to `#pitch`, `#theta` to `#twist`, and `#q` to `#to_q`
- **Breaking:** rename the `HlxParams.hlxparams` method to `.new`
- Set the `description` argument as optional in the `Templates::Residue`'s constructor
- Improve bond order assignment following OpenBabel's algorithm
- Improve the valence model. Includes several changes in 40add48 like explicit valences for every element, single and multiple valences, refactor element generation code, better bond perception, etc.
- Improve bond detection by introducing a maximum number of bonds per element and better target valence calculation
- Improve formal charge assignment based on valence electrons
- Refactor template structure specification parsing into the `Templates::SpecParser` class
- Optimize topology detection by trying larger templates first

#### Input/output

- **Breaking:** remove `Spatial::Grid::Reader` and `Structure::Reader` types. Use the corresponding format readers instead, e.g., `Cube::Reader`, `PDB::Reader`
- **Breaking:** rename the `FileFormat` enum to `Format`
- **Breaking:** rename the `Reader` type to `FormatReader`
- **Breaking:** rename the `Writer` type to `FormatWriter`
- **Breaking:** refactor the `FormatReader` and `FormatWriter`'s APIs
- **Breaking:** rename the `FileType` annotation to `RegisterFormat`
- **Breaking:** refactor the `RegisterFormat` annotation to work on namespaces
- **Breaking:** require the `extension` argument of the `RegisterFormat` annotation to start with a dot
- **Breaking:** use the `Structure#source_file` property in the STRIDE, PyMOL and VMD writers
- Refactor the `RegisterFormat` annotation to work on types outside the `Chem` namespace

#### Spatial

- **Breaking:** remove the `Basis` type. Use the `Mat3` type instead
- **Breaking:** remove the `Lattice` type. Use the `Parallelepiped` type instead
- **Breaking:** remove the `Bounds` type. Use the `Parallelepiped` type instead
- **Breaking:** remove the `Vec3#*(Transform)` method. Use the `Vec3#transform` method
- **Breaking:** rename the `Vector` type to `Vec3`
- **Breaking:** rename the `Quaternion` type to `Quat`
- **Breaking:** rename `AffineTransform` type to `Transform`
- **Breaking:** rename `squared_distance` methods to ` #distance2`
- **Breaking:** refactor `Transform`'s API (too many changes to list)
- **Breaking:** standardize transformation methods like `#translate`, `#rotate`, etc. in spatial objects (#184, #186)
- **Breaking:** remove `Vec3#to_fract(cell)` and `#to_cart(cell)` methods. Use the `cell.fract(vec)` and `cell.cart(vec)` methods instead
- **Breaking:** accept unit cell as the first argument in measurement methods, e.g., `Spatial.angle(cell, a, b, c)`
- **Breaking:** refactor the `KDTree` type to use an array of vectors
- Refactor the `PeriodicKDTree` type out of the `KDTree` type to handle neighbor search in periodic coordinates

#### Misc

- Update to Crystal v1.6
- Tag specs that test code generation

### Added

#### Core

- Support metadata in `Structure` and `Atom` types
- Update the residue's position after changing the number and insertion code
- Add the `Membrane` member to the `ResidueType` enum
- Add the `Atom#typename` property
- Add `#spec` method to return the specification of a chain, residue, and atom
- Add the `Atom#degree` method
- Add element question methods to `Atom`, e.g., `Atom#carbon?`
- Add residue type question methods to `Atom`, e.g., `Atom#protein?`
- Add the `Atom#het?` and `Atom#water?` question methods
- Add the `Bond#atoms` method
- Add the `Residue#code` method to get one-letter residue code
- Add the `Residue#<=>` method to allow sorting
- Add the `Residue#het?` and `Residue#water?` question methods
- Add the `Residue#each_bonded_residue` method
- Add the `Residue#pred?` and `#succ?` question methods
- Renumber residues by the given block (via the `#renumber_residues_by` method) (#129)
- Set coordinates of a collection of atoms (see `AtomCollection#coords=` method)
- Extract a subset of a structure (see `Structure#extract(&)` method)

#### Topology

- Support kekulization for aromatic rings
- Support symmetry in residue templates (e.g., side chain of Phe)
- Support aliases in residue templates (#127)
- Support template terminations (see the `Templates::Ter` type)
- Define a smiles-like notation (e.g., parentheses for branches) for defining residue templates
- Create a template from a `Residue` instance
- Load residue templates from YAML and structure files
- Guess the root and link bond of a residue template based on the bonding complexity
- Add the `Topology` type to hold topology information
- Add the `TemplateRegistry` type for handling residue templates
- Add the `Angle`, `Dihedral`, etc. types for representing connectivity

#### Input/output

- Read/write DCD, Extended XYZ (#105), PSF, MDL Mol, and SDF formats
- Add the `PullParser` type for parsing plain text files with better error tracking
- Define an interface for wrapping an IO via the `IO::Wrapper` mixin
- Define an interface for reading and writing multiple entries (PDB, Mol2, etc.) via the `FormatReader::MultiEntry` and `FormatWriter::MultiEntry` mixins, respectively
- Define an interface for indexable file formats (DCD) via the `FormatReader::Indexable` mixin
- Define an interface for reading head and attached objects via the `FormatReader::Attached` and `FormatReader::Headed` mixins, respectively
- Generate `.read` and `#write` methods on types referenced by readers and writers, respectively
- Generate `.from_*` and `#to_*` methods on `Array` for formats with multiple entries
- Read the grid header (as `Grid::Info`) from volumetric data formats (Cube, Chgcar, etc.)
- Read the structure from volumetric data formats (Cube, Chgcar, etc.)
- Read the experimental data (as `Structure::Experiment`) from PDB
- Support binary encoding via `.from_io` and `#to_io` methods
- Add the `Structure#source_file` and `Grid#source_file` properties
- Get file patterns, get reader and writer types for a given format, check if a format encodes a specific type, etc. via the `Format` enum
- Specify atom ordering when writing Poscar
- Read/write unit cell in Mol2
- Support atomic numbers in XYZ
- Print filename in STRIDE output
- Write TER PDB records for each fragment in PDB (#89)

#### Spatial

- Compute optimal RMSD via the QCP method (see the `Spatial.qcp` and `CoordinatesProxy#rmsd` methods)
- Superimpose coordinates (see the `Transform#aligning` and `CoordinatesProxy#align_to` methods)
- Add the `Spatial::Mat3` type for representing a 3x3 matrix
- Add the `Parallelepiped` type for representing a region in 3d space
- Accept Euler angles as argument in rotation methods
- Add arithmetic operations between sizes (#170)
- Compute projection of a vector
- Query alignment of a vector with respect to axes and planes
- Generate a random vector
- Align pairs of vectors via the `Quat.aligning` method
- Convert a quaternion to a 3x3 rotation matrix
- Get the rotation and translation components of transformation
- Add component-wise `#transform(&)` methods to `Size3` and `Vec3` types (#162, #169)
- Unwrap periodic coordinates based on connectivity

#### Misc

- Add the `Enumerable#average` and `Enumerable#mean` methods
- Add the `#close_to?` method to several numeric types such as `Float`, `Vec3`, etc.
- Add specs for the `RegisterFormat` annotation and related code generation
- Add the `assert_error` and `assert_code` spec helpers to check code compilation
- Add the `spec_file` spec helper
- Add convenient spec helpers like `vec3`, `bounds`, `size3`, etc.
- Deploy docs to [GitHub pages](https://franciscoadasme.github.io/chem.cr)

### Removed

#### Core

- **Breaking:** remove special cases for unknown elements in PDB (i.e., `PeriodicTable::D ` and `PeriodicTable::X`)
- **Breaking:** remove the `Element#ionic` property

#### Topology

- **Breaking:** remove the `Protein::Sequence` type
- **Breaking:** remove the `Topology::Patcher` type
- **Breaking:** remove the `structure` argument from the `Structure#Builder`'s constructor

#### Input/output

- **Breaking:** remove the `IO` namespace
- **Breaking:** remove the `DFTB` namespace

#### Spatial

- **Breaking:** remove the `Linalg::Matrix` dynamic matrix type
- **Breaking:** remove the `PBC` module
- **Breaking:** remove non-modifying methods from `CoordinatesProxy` type

#### Misc

- Move the PSIQUE executable to the https://github.com/franciscoadasme/psique repository
- Remove spec aliases
- Remove ton of unused code

### Fixed

#### Topology

- Check for protein gap based on connectivity (not residue numbers) in DSSP
- Skip bond order assignment if a protein chain has no hydrogens
- Fix bond check between two atoms
- Fix charge of the Arginine template
- Fix calculating pitch for periodic 2-residue peptides (#97)
- Add bonds to terminal residues in periodic structures
- Raise if template bond specification refer to the same atom
- Support periodicity in atom hybridization guessing (#164)
- Cache element count to assign atom name (#182)
- Increase bond order of multi-valent atoms first
- Avoid duplicate atom names in hydrogen name generation
- Fix implicit hydrogen count when building a template

#### Input/output

- **Breaking:** raise if structure has no bonds when writing Mol2
- Write `MODEL` PDB records when appropriate
- Ignore CRYST1 PDB record if it has default values (#161)
- Ignore empty REMARK 2 record in PDB
- Check for invalid values in unit cell size and angles in PDB
- Ignore alternate position if the occupancy equals one in PDB
- Print trailing whitespace on several records in PDB
- Align unit cell to the XY plane when writing PDB
- Read a zero-sized cell as nil in PDB (#189)
- Fix reading PDB record on an empty line
- Read PDB without occupancy/bfactor (#179)
- Remove restriction of atom name pattern in Mol2
- Do not reorder atoms when writing POSCAR

#### Spatial

- Return a zero matrix for a zero quaternion in the `Quat#to_mat3` method
- Fix computation of PBC neighboring images
- Fix computation of coordinate alignment transformation (#183)

## [v0.5.6] - 2021-03-01

### Changed

#### Misc

- Update to Crystal v0.36.1

## [v0.5.5] - 2021-03-01

### Added

#### Topology

- Add hydrogen bond restriction for beta-strand assignment to PSIQUE

### Fixed

#### Topology

- Fix templates of Cysteine and Methionine

## [v0.5.4] - 2020-11-17

### Changed

#### Misc

- Improve installation instructions and other minor tweaks in README

## [v0.5.3] - 2020-11-16

### Changed

#### Misc

- Update PSIQUE cli

## [v0.5.2] - 2020-11-16

### Changed

#### Topology

- Update PSIQUE documentation

## [v0.5.1] - 2020-11-16

This patch release is done in preparation for article submission of PSIQUE.

### Changed

#### Topology

- Standardize secondary structure colors

#### Misc

- Update PSIQUE cli

### Added

#### Input/output

- Write VMD script file format

## [v0.5.0] - 2020-11-16

This release introduces a full rewrite of text parsing and optimizations to the secondary structure assignment method among other minor changes.

Additionally, from this release onwards, release binaries are built automatically.

### Changed

#### Topology

- **Breaking**: Move `ResidueCollection#renumber_by_connectivity` method to `Structure` and `Chain` types (#93)
- **Breaking:** Rename QUESSO to PSIQUE
- Pre-compute several geometric parameters in PSIQUE (#91)
- Do not check bounds on reassignment in PSIQUE

#### Input/output

- **Breaking:** Full rewrite of text parsing (#94)
- **Breaking:** Use lowercase not underscore for format names

### Added

#### Topology

- Get residue-wise fragments via `ResidueCollection#each_residue_fragment` and `#residue_fragments` (#92)
- Add `split_chains` argument to `Structure#renumber_by_connectivity` method (#93)

#### Input/output

- Write PyMOL file format
- Write STRIDE file format

### Fixed

#### Input/output

- Handle short lines (<54 characters) in PDB

## [v0.4.1] - 2020-09-07

### Changed

#### Topology

- Check entity before deleting entry in cache table (#88)

### Fixed

#### Input/output

- Support left-justified element in PDB (#87)

## [v0.4.0] - 2020-08-22

### Changed

#### Topology

- **Breaking:** Rename `Residue#secondary_structure` type to `#sec`
- **Breaking:** Refactor secondary structure enum to include handedness
- **Breaking:** Rename `SecondaryStructure#dssp` to `#code`
- **Breaking:** Rename `Helix2_7` in secondary structure enum to `HelixGamma`
- Include handedness and type in secondary structure equality

### Added

#### Topology

- Iterate over secondary structure
- Add chirality residue methods
- Add secondary structure type
- Define secondary structure information like minimum size
- Report chirality in DSSP
- Add QUESSO method for secondary structure assignment

#### Input/output

- Write secondary structure in PDB header

#### Spatial

- Calculate improper angles
- Load matrix from a file

### Fixed

#### Topology

- Use sequence order in `Residue#previous` and `#next` methods if link bond is not set

#### Input/output

- Handle missing remark id in PDB
- Do not skip to end of file after reading POSCAR

## [v0.3.0] - 2020-04-30

This release introduces some big changes to code hierarchy and topology perception, and new features like support for volumetric data.

### Changed

#### Core

- **Breaking:** Rename `Experiment::Kind` enum to `Experiment::Method`
- **Breaking:** Move valency-related methods to the `Atom` type
- Change `Residue#previous` and `#next` to be computed properties (#70)
- Change `Atom#mass` and `#vdw_radius` properties to be mutable (#72)

#### Topology

- **Breaking:** Merge `Topology::Builder` functionality into `Structure::Builder` type
- **Breaking:** Rename `Templates::Residue` type to `ResidueType`
- **Breaking:** Merge topology assignment from templates into `Structure::Builder` type
- **Breaking:** Move topology perception functionality to `Topology::Perception` (#68)
- Guess bonds for all atoms
- Guess topology by default
- Pre-calculate maximum covalent distance to speed up bond search (#57)

#### Input/output

- **Breaking:** Drop builder pattern from writers
- **Breaking:** Refactor parsers and writers to be generic types

#### Spatial

- **Breaking:** Rename `Vector#resize(by)` method to `#pad`
- **Breaking:** Rename `Size3D` method to `Size`

#### Misc

- **Breaking:** Refactor code folder structure

### Added

#### Core

- Add `Structure#clone` method

#### Topology

- Get bonded residues (#60, #66)
- Rename unidentified atoms (#29)
- Guess bonds of unidentified atoms (#55)
- Guess residues of unidentified atoms based on connectivity

#### Input/output

- Add writer formatting helper methods
- Add specialized fast ASCII parser
- Read/write DX file format
- Specify file format when reading/writing
- Read/write CHGCAR/LOCPOT file format
- Read/write Gaussian's Cube file format (#35)
- Guess file format from filename (#37, #53)

#### Spatial

- Add `Spatial::Grid` for representing volumetric data
- Add `Lattice#origin` property
- Add `Lattice#volume` computed property
- Re-add basic `Basis` impl.
- Add vector PBC image methods
- Add `*_with_distance` methods to `KDTree` type
- Add `Bounds` type for the bounds (cuboid) of a spatial object
- Support PBC in `KDTree` type
- Add coordinates centering methods (#30)
- Support PBC in measurements (#71)

#### Misc

- Added benchmarks

### Removed

#### Input/output

- **Breaking:** Remove string content as parser argument

### Fixed

#### Topology

- **Breaking:** Enforce chain id to be alphanumeric
- Update `Residue#type` property after changing its name
- Avoid stack overflow in fragment detection for large structures
- Guess type of unknown residues (#69)

#### Input/output

- Flush an IO before closing it
- Fix misalignment for four-letter residue names in PDB (#51)
- Preserve atom order when writing POSCAR (#52)

#### Spatial

- Fix PBC image for atom outside primary unit cell (#56)

## [v0.2.0] - 2019-11-08

This release introduces some big changes to topology handling and file formats.

### Changed

#### Topology

- Add formal and partial charge properties to `Atom` type
- Support multiple valencies
- Support ionic elements
- Guess bonds from geometry
- Guess topology from connectivity
- Add residue template root
- Support terminal groups in templates
- Add mutating methods
- Add residue renumbering by connectivity
- Add STRIDE (external) support for secondary structure assignment

#### Input/output

- **Breaking:** use annotations for associating parsers/writers to file formats
- **Breaking:** Implement the `Iterator` mixin in parsers
- Use `Structure::Builder` in parsers
- Simplify PDB parsing while avoiding edge cases

#### Spatial

- **Breaking:** Add `Spatial::CoordinatesProxy` type to centralize coordinates manipulation/transformation
- Optimize PBC wrap for non-cuboid lattices

### Added

#### Core

- Add sizing methods to collections
- Include collection functionality into views
- Add `#dig` methods

#### Input/output

- Define methods for reading/writing on encoded types via macros
- Define specialized parser mixins (e.g., text parser, column-based parser, ASCII parser)
- Read/write XYZ file format
- Read/write Mol2 file format
- Read/write DFTB+'s Gen file format
- Write PDB file format
- Set element order when writing POSCAR
- Add chain/conformation/het argument when reading PDB
- Support PDB hybrid36 numbering
- Track cursor in some parsers

#### Spatial

- Add PBC unwrapping
- Add PBC-related methods to `Vector` (e.g., `#to_fractional`, `#wrap`)

### Removed

#### Input/output

- **Breaking:** Remove support for residue alternate conformations
- **Breaking:** Remove coordinate system property from POSCAR

#### Spatial

- **Breaking:** Remove basis-related code
- **Breaking:** Remove inverse transformation caching
- **Breaking:** Remove scale factor and space group from `Lattice` type

### Fixed

#### Topology

- Allow three-letter atom names

## [v0.1.0] - 2019-04-26

_Initial release_

### Added

- Access structure topology hierarchically
- Guess topology based on templates
- Read/write standard file formats like PDB
- Support basic spatial measurements and transformations

[v0.6.0]: https://github.com/franciscoadasme/chem.cr/releases/tag/v0.6.0
[v0.5.6]: https://github.com/franciscoadasme/chem.cr/releases/tag/v0.5.6
[v0.5.5]: https://github.com/franciscoadasme/chem.cr/releases/tag/v0.5.5
[v0.5.4]: https://github.com/franciscoadasme/chem.cr/releases/tag/v0.5.4
[v0.5.3]: https://github.com/franciscoadasme/chem.cr/releases/tag/v0.5.3
[v0.5.2]: https://github.com/franciscoadasme/chem.cr/releases/tag/v0.5.2
[v0.5.1]: https://github.com/franciscoadasme/chem.cr/releases/tag/v0.5.1
[v0.5.0]: https://github.com/franciscoadasme/chem.cr/releases/tag/v0.5.0
[v0.4.1]: https://github.com/franciscoadasme/chem.cr/releases/tag/0.4.1
[v0.4.0]: https://github.com/franciscoadasme/chem.cr/releases/tag/0.4.0
[v0.3.0]: https://github.com/franciscoadasme/chem.cr/releases/tag/0.3.0
[v0.2.0]: https://github.com/franciscoadasme/chem.cr/releases/tag/0.2.0
[v0.1.0]: https://github.com/franciscoadasme/chem.cr/releases/tag/0.1.0
