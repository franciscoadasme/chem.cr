# chem.cr

[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/franciscoadasme/chem.cr/Crystal%20CI.svg)](https://github.com/franciscoadasme/chem.cr/actions?query=workflow%3A%22Crystal+CI%22)
[![Version](https://img.shields.io/github/v/release/franciscoadasme/chem.cr.svg?label=version)](https://github.com/franciscoadasme/chem.cr/releases/latest)
[![License](https://img.shields.io/github/license/franciscoadasme/chem.cr.svg)](https://github.com/franciscoadasme/chem.cr/blob/master/LICENSE)

A modern library written in [Crystal](https://crystal-lang.org) primarily
designed for manipulating molecular files created by computational chemistry
programs. It aims to be both fast and easy to use.

**IMPORTANT**: this library is in alpha stage, meaning that there is missing
functionality, documentation, etc. and there will be breaking changes.

## Features

- Object-oriented API for accessing and manipulating molecules. It follows the
  topology commonly used in [Protein Data
  Bank](https://en.wikipedia.org/wiki/Protein_Data_Bank_(file_format)) (PDB)
  file format: Structure (or model) → Chain → Residue → Atom.
- Type safety (assigning a number to the atom's name will result in a
  compilation error)
- Support for periodic molecular structures
- Support for several file formats (and many more to come...)
- Iterator-based file reading (avoids reading all data into memory)
- Fast performance (see Benchmarks below)

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  chem:
    github: franciscoadasme/chem.cr
    version: ~> 0.1
```

### Requirements

- To run STRIDE analysis, you'll need to set `STRIDE_BIN` to the STRIDE
  executable path.

## Usage

First require the `chem` module:

```crystal
require "chem"
include Chem # avoids typing Chem:: prefix
```

Let's first read a structure:

```crystal
st = Strucuture.read "/path/to/file.pdb"
st # => <Structure "1cbn": 644 atoms, 47 residues, periodic>
```

You can also use a custom read method that accepts specific options:

```crystal
Structure.from_pdb "/path/to/file.pdb"
Structure.from_pdb "/path/to/file.pdb", chains: ['A'] # read only chain A
Structure.from_pdb "/path/to/file.pdb", het: false # skip HET atoms
Structure.from_pdb "/path/to/file.pdb", alt_loc: 'A' # select alternate location A
```

You can access PDB header information via the `#experiment` property:

```crystal
if expt = st.experiment # check if experiment data is present
  expt.title # => "ATOMIC RESOLUTION (0.83 ANGSTROMS) CRYSTAL STRUCTURE..."
  expt.kind # => XRayDiffraction
  expt.resolution # => 0.83
  expt.deposition_date # => 1991-10-11
  ...
end
```

You can also read many structures at once:

```crystal
# read all models
Array(Structure).from_pdb "/path/to/file.pdb"
# read 2th and 5th models
Array(Structure).from_pdb "/path/to/file.pdb", indexes: [1, 4]
```

Alternatively, you could use an IO iterator to read one by one:

```crystal
PDB::Parser.new("/path/to/file.pdb").each { |st| ... }
PDB::Parser.new("/path/to/file.pdb").each(indexes: [1, 4]) { |st| ... }
```

### Topology access

You can access topology objects using the bracket syntax (like a hash or
associative array or dictionary):

```crystal
st['A'] # => <Chain A>
st['A'][10] # => <Residue A:ARG10>
st['A'][10]["CA"] # => <Atom A:ARG10:CA(146)>
```

Alternatively, you can use the `#dig` and `#dig?` methods:

```crystal
st.dig 'A' # => <Chain A>
st.dig 'A', 10 # => <Residue A:ARG10>
st.dig 'A', 10, "CA" # => <Atom A:ARG10:CA(146)>

st.dig 'A', 10, "CJ" # causes an error because "CJ" doesn't exist
st.dig? 'A', 10, "CJ" # => nil
```

Each topology object have several modifiable properties:

```crystal
atom = st.dig 'A', 10, "CA"
atom.element.name # => Carbon
atom.coords # => [8.47 4.577 8.764]
atom.occupancy # => 1.0
atom.bonded_atoms.map &.name # => ["N", "C", "HA", "CB"]
```

Thanks to Crystal's powerful standard library, manipulating topology objects is
very easy:

```crystal
# ramachandran angles
st.residues.map { |r| {r.phi, r.psi} } # => [{129.5, 90.1}, ...]
# renumber residues starting from 1
st.residues.each_with_index { |res, i| res.number = i + 1 }
# constrain Z-axis
st.atoms.each { |atom| atom.constraint = :z }
# total charge
st.atoms.sum_of &.partial_charge
# iterate over secondary structure elements
st.residues.chunk(&.sec).each do |sec, residues|
  sec # => HelixAlpha
  residues # => [<Residue A:ARG1>, <Residue A:LEU2>, ...]
end
```

Here `#residues` and `#atoms` return an array of `Residue` and `Atom` instances,
respectively. Collections also provide iterator-based access, e.g.,
`#each_atom`, that avoids expensive memory allocations:

```crystal
st.atoms.any? &.constraint # array allocation to just check a condition
st.each_atom.any? &.constraint # faster!
```

### Atom selection

Right now, there is no custom language to select a subset of atoms. However,
thanks to Crystal, one can achieve a similar result with an intuitive syntax:

```crystal
st.atoms.select { |atom| atom.partial_charge > 0 }
# or
st.atoms.select &.partial_charge.>(0)
# compared to a custom language
st.atoms.select "partial_charge > 0"

# select atoms within a cylinder of radius = 4 A and centered at the origin
st.atoms.select { |atom| atom.x**2 + atom.y**2 < 4 }
# compared to a custom language
st.atoms.select "sqrt(x) + sqrt(y) < 4" # or "x**2 + y**2 < 4"
```

One advantage to using Crystal itself is that it provides type-safety: doing
something like `atom.name**2` will result in a compilation error, whereas using
a custom language will probably produce a confusing error during runtime.
Additionally, the code block can be as big and complex as necessary with
multiple intermediary computations. Furthermore, a negative condition may be
confusing and not be trivial to write, but in Crystal you would simply use
`#reject` instead.

Finally, the above also works for chain and residue collections:

```crystal
# select protein chains
st.chains.select &.each_residue.any?(&.protein?)
# select only solvent residues
st.residues.select &.solvent?
# select residues with any atom within 5 A of the first CA atom
# (this is equivalent to "same residue as" or "fillres" in other libraries)
ca = st.dig 'A', 1, "CA"
st.residues.select do |res|
  res.each_atom.any? { |atom| Spatial.distance(atom, ca) < 5 }
end
# or
st.atoms.select { |atom| Spatial.distance(atom, ca) < 5 }.residues
```

### Coordinates manipulation

All coordinates manipulation is done using a `CoordinatesProxy` instance,
available for any atom collection (i.e., structure, chain or residue) via
`#coords`:

```crystal
# geometric center
st.coords.center
# center at origin
st.coords.translate! -st.coords.center
# wraps atoms into the primary unit cell
st.coords.wrap
...
```

## Benchmarks

`chem.cr` is implemented in pure Crystal, making it as fast or even faster than
some C-powered packages.

The benchmark is designed as follows:

* The tests are implemented using the functionality documented by each library
  in tutorials, examples, etc. Optimized versions may be faster but require
  advanced (possibly undocumented) usage.
* Tests are run ten times (except for 1HTQ, 3 times) and the elapsed time for
  each run is averaged.
* Parsing PDB files
  * [1CRN](http://www.rcsb.org/pdb/explore/explore.do?structureId=1crn) -
    hydrophobic protein (327 atoms).
  * [3JYV](http://www.rcsb.org/pdb/explore/explore.do?structureId=3jyv) - 80S
    rRNA (57,327 atoms).
  * [1HTQ](http://www.rcsb.org/pdb/explore/explore.do?structureId=1htq) -
    multicopy glutamine synthetase (10 models of 97,872 atoms).
* Counting the number of alanine residues in adenylate kinase (1AKE, 3816
  atoms).
* Calculating the distance between residues 50 and 60 of chain A in adenylate
  kinase (1AKE, 3816 atoms).
* Calculating the Ramachandran phi/psi angles in adenylate kinase (1AKE, 3816
  atoms).

**IMPORTANT**: direct comparison of parsing times should be taken with a grain
of salt because each library does something slightly different, e.g., error
checking. Some of this functionality is listed below. Nonetheless, these results
gives an overall picture in terms of the expected performance.

|                      | Biopython | chem.cr | Chemfiles | MDAnalysis | MDTraj | schrodinger |   VMD |
| -------------------- | --------: | ------: | --------: | ---------: | -----: | ----------: | ----: |
| Parse 1CRN [ms]      |     6.521 |   1.028 |     1.668 |      5.059 | 11.923 |      45.497 | 2.285 |
| Parse 3JYV [s]       |     0.837 |   0.086 |     0.199 |      0.404 |  1.490 |       0.766 | 0.162 |
| Parse 1HTQ [s]       |    16.146 |   1.673 |     2.540 |      1.387 | 18.969 |      11.997 | 0.236 |
| Count [ms]           |     0.210 |   0.009 |     0.322 |      0.041 |  0.079 |      25.997 | 0.165 |
| Distance [ms]        |     0.172 |   0.000 |     1.016 |      0.382 |  0.990 |      43.101 | 0.379 |
| Ramachandran [ms]    |   110.450 |   0.607 |         - |    690.201 |  4.947 |      68.758 | 1.814 |
|                      |           |         |           |            |        |             |       |
| License              | Biopython |     MIT |       BSD |      GPLv2 |   LGPL | Proprietary |   VMD |
| Parse Header         |       yes |     yes |       yes |         no |     no |          no |    no |
| Parse CONECT         |        no |     yes |       yes |         no |    yes |         yes |   yes |
| Guess bonds          |        no |      no |       yes |         no |    yes |         yes |   yes |
| Hybrid36             |        no |     yes |        no |        yes |     no |          no |    no |
| Hierarchical parsing |       yes |     yes |        no |         no |     no |          no |    no |
| Supports disorder    |       yes |     yes |        no |         no |    yes |         yes |    no |

Latest update: 2019-11-10

Scripts and details are provided at [pdb-bench](https://github.com/franciscoadasme/pdb-bench).

## Roadmap

### Topology manipulation

- [x] Automatic connectivity detection (includes periodic systems)
- [x] Automatic bond order assignment
- [x] Residue templates (basic impl.)
  - [ ] Custom terminal groups
- [x] Automatic topology assignment (chain, residue names, atom names) based on
  residue templates
- [ ] Atom wildcards (`"C*"` will select `"C"`, `"CA"`, `"CB"`, etc.)
- [ ] Atom selection language

### Input and Output

- [x] Automatic file format detection
- [x] Support for per-file format options (e.g., select PDB chain)
- [x] Friendly errors (message with error location)
- [x] Iterator-based IO
- [ ] Compressed files (.gz and .xz)
- [ ] Trajectory support

#### File formats

- [x] DFTB+'s Gen format
- [ ] Macromolecular Crystallographic Information Framework (CIF)
- [ ] MacroMolecular Transmission Format (MMTF)
- [x] PDB
- [x] Tripos Mol2
- [x] VASP's Poscar
- [x] XYZ
- [ ] and many more

### Analysis

- [x] Coordinates manipulation (via `CoordinatesProxy`)
- [x] Spatial calculations (distance, angle, dihedral, quaternions, affine
  transformations)
- [x] Periodic boundary conditions (PBC) support (topology-aware wrap and
  unwrap)
- [x] Secondary structure assignment
  - [x] DSSP (native implementation)
  - [x] STRIDE (uses external program for now)
- [x] Nearest neighbor search (via native k-d tree impl.)
- [ ] RMSD
- [ ] Structure superposition
- [ ] Intermolecular interactions (H-bonds, etc.)
- [ ] Volumetric data
- [ ] Parallel processing

### Other

- [ ] Documentation
- [ ] Guides
- [ ] Workflows (handle calculation pipelines)
- [ ] More tests

## Testing

Run the tests with `crystal spec`.

## Similar software

There are several libraries providing similar functionality. Here we list some
of them and provide one or more reasons for why we didn't use them. However,
each one of them is good in their own right so please do check them out if
`chem.cr` does not work for you.

- [Chemfiles](http://chemfiles.org/) is a library for reading and writing
  chemistry files written in C++, but can also be used from other languages such
  as Python. It is mainly focused on simulation trajectories and does not
  provide an object-oriented topology access.
- [OpenBabel](https://openbabel.org/wiki/Main_Page) is a massive C++ library
  providing support for more than 110 formats. Its API is very complex to use.
- [MDTraj](http://mdtraj.org/latest/), [MDAnalysis](http://www.mdanalysis.org/),
  [cclib](https://cclib.github.io), [pymatgen](https://pymatgen.org),
  [prody](http://prody.csb.pitt.edu), [Biopython](https://biopython.org) and
  more are written in Python, which usually means two things: (1) no type safety
  makes them sometimes difficult to use if there is not enough documentation
  (more common than one may think), (2) one usually have to deal with C for
  performance critical code.
- [VMD](http://www.ks.uiuc.edu/Research/vmd/) and
  [Schrodinger](https://schrodinger.com/) are very popular software for
  molecular visualization that provide an API in Tcl and/or Python to manipulate
  molecules. However, these usually suffer from poor documentation.

## Contributing

1. Fork it (<https://github.com/franciscoadasme/chem.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [franciscoadasme](https://github.com/franciscoadasme) Francisco Adasme -
  creator, maintainer

## License

Licensed under the MIT license, see the separate LICENSE file.
