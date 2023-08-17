# Changelog

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
