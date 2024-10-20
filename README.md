# chem.cr

[![Crystal CI](https://github.com/franciscoadasme/chem.cr/actions/workflows/crystal.yml/badge.svg)](https://github.com/franciscoadasme/chem.cr/actions/workflows/crystal.yml)
[![Version](https://img.shields.io/github/v/release/franciscoadasme/chem.cr.svg?label=version)](https://github.com/franciscoadasme/chem.cr/releases/latest)
[![License](https://img.shields.io/github/license/franciscoadasme/chem.cr.svg)](https://github.com/franciscoadasme/chem.cr/blob/master/LICENSE)

[Features](#features) |
[Installation](#installation) |
[Usage](#usage) |
[Benchmark](#benchmark) |
[Roadmap](#roadmap) |
[Similar software](#similar-software) |
[Testing](#testing) |
[Contributing](#contributing) |
[Contributors](#contributors) |
[License](#license)

A modern library written in [Crystal][1] for manipulating molecular files used in computational chemistry and biology.
It aims to be both fast and easy to use.

> [!NOTE]
> PSIQUE was moved to the [psique](https://github.com/franciscoadasme/psique) repository.

## Features

- Object-oriented API for accessing and manipulating molecules.
  It follows the topology commonly used in [Protein Data Bank][2] (PDB) file format: Structure (or model) → Chain → Residue → Atom.
- Type safety (assigning a number as the atom's name will result in an error at compilation time).
- Support for periodic molecular structures.
- Support for common molecular file formats (PDB, SDF, etc.).
- Spatial measurements (distance, RMSD, alignment).
- Template-based topology reconstruction.
- Volumetric data.
- Fast performance (see [Benchmark](#benchmark) below).

> [!IMPORTANT]
> This library is in alpha stage, meaning that there is missing functionality, documentation, etc. and there will be breaking changes.

## Installation

Ensure the Crystal compiler is installed:

```console
$ crystal -v
Crystal 1.13.1 [0cef61e51] (2024-07-12)

LLVM: 18.1.6
Default target: x86_64-unknown-linux-gnu
```

If the command fails, you need to install the crystal compiler by
following [these steps][3].

Crystal requires listing the dependencies in the `shard.yml` file.
Let's create a new project:

```console
$ crystal init app myapp
    create  myapp/.gitignore
    create  myapp/.editorconfig
    create  myapp/LICENSE
    create  myapp/README.md
    create  myapp/.travis.yml
    create  myapp/shard.yml
    create  myapp/src/myapp.cr
    create  myapp/src/myapp/version.cr
    create  myapp/spec/spec_helper.cr
    create  myapp/spec/myapp_spec.cr
Initialized empty Git repository in /home/crystal/myapp/.git/
$ cd myapp
```

Add the following to the application's `shard.yml`:

```yaml
dependencies:
  chem:
    github: franciscoadasme/chem.cr
```

Then, resolve and install missing dependencies:

```console
$ shards install
```

Dependencies are installed into the `lib` folder.
More about dependencies at the [Requiring files][4] guide.

### Requirements

- To run STRIDE analysis, you'll need to set `STRIDE_BIN` to the STRIDE
  executable path.

## Usage

First require the `chem` module:

```crystal
require "chem"
```

Let's first read a structure:

```crystal
struc = Chem::Structure.read "file.pdb"
struc # => <Structure "1cbn": 644 atoms, 47 residues, periodic>
```

You can also use a custom `.from_*` method to specify reading options when available:

```crystal
Chem::Structure.from_pdb "/path/to/file.pdb"
Chem::Structure.from_pdb "/path/to/file.pdb", chains: ['A'] # reads only chain A
Chem::Structure.from_pdb "/path/to/file.pdb", het: false    # skips HET atoms
Chem::Structure.from_pdb "/path/to/file.pdb", alt_loc: 'A'  # selects alternate location A
```

You can access PDB header information via the `#experiment` property:

```crystal
if expt = struc.experiment # checks if experiment data is present
  expt.title               # => "ATOMIC RESOLUTION (0.83 ANGSTROMS) CRYSTAL STRUCTURE..."
  expt.kind                # => XRayDiffraction
  expt.resolution          # => 0.83
  expt.deposition_date     # => 1991-10-11
end
```

You can also read many structures at once:

```crystal
# read all models
Array(Chem::Structure).from_pdb "/path/to/file.pdb"
# read 2th and 5th models
Array(Chem::Structure).from_pdb "/path/to/file.pdb", indexes: [1, 4]
```

Alternatively, you could use the reader class directly to read one by one via the `#each` method:

```crystal
Chem::PDB::Reader.new("/path/to/file.pdb").each { |struc| ... }
Chem::PDB::Reader.new("/path/to/file.pdb").each(indexes: [1, 4]) { |struc| ... }
```

### Topology access

You can access topology objects using the `#dig` methods:

```crystal
struc.dig('A')           # => <Chain A>
struc.dig('A', 10)       # => <Residue A:ARG10>
struc.dig('A', 10, "CA") # => <Atom A:ARG10:CA(146)>

struc.dig 'A', 10, "CJ"  # raises a KeyError because "CJ" doesn't exist
struc.dig? 'A', 10, "CJ" # => nil
```

Each topology object have several modifiable properties:

```crystal
atom = struc.dig 'A', 10, "CA"
atom.element.name            # => "Carbon"
atom.pos                     # => [8.47 4.577 8.764]
atom.occupancy               # => 1.0
atom.bonded_atoms.map &.name # => ["N", "C", "HA", "CB"]

atom.residue.number   # => 10
atom.residue.protein? # => true
atom.residue.pred     # => <Residue A:PHE9>

atom.chain.id            # => 'A'
atom.chain.residues.size # => 152
```

Thanks to Crystal's powerful standard library, manipulating topology objects is very easy:

```crystal
# select chains longer than 50 residues
struc.chains.select { |chain| chain.residues.size > 50 }
# ramachandran angles
struc.residues.map { |residue| {residue.phi, residue.psi} } # => [{129.5, 90.1}, ...]
# renumber residues starting from 1
struc.residues.each_with_index { |residue, i| residue.number = i + 1 }
# constrain Z-axis
struc.atoms.each &.constraint=(:z)
# total partial charge
struc.atoms.sum_of &.partial_charge
# iterate over secondary structure elements
struc.residues.chunk(&.sec).each do |sec, residues|
  sec      # => HelixAlpha
  residues # => [<Residue A:ARG1>, <Residue A:LEU2>, ...]
end
```

The `#chains`, `#residues`, and `#atoms` methods return an array view of `Chain`, `Residue` and `Atom` instances, respectively.
Refer to the [Enumerable](https://crystal-lang.org/api/latest/Enumerable.html) and [Indexable](https://crystal-lang.org/api/latest/Indexable.html) modules for more information about available methods.

### Atom selection

Unlike most other libraries for computational chemistry, there is no text-based language to select a subset of atoms (for now).
However, one can achieve a rather similar experience using Crystal's own syntax:

```crystal
struc.atoms.select { |atom| atom.partial_charge > 0 }
# or (Crystal's short block syntax)
struc.atoms.select &.partial_charge.>(0)
# compared to a custom language
struc.atoms.select "partial_charge > 0"

# select atoms within a cylinder of radius = 4 A along the Z axis and centered at the origin
struc.atoms.select { |atom| atom.x**2 + atom.y**2 < 4 }
# compared to a custom language
struc.atoms.select "sqrt(x) + sqrt(y) < 4" # or "x**2 + y**2 < 4"
```

Using Crystal itself for selection provides one big advantage: type-safety.
Doing something like `atom.name**2` will result in an error during _compilation_, pointing exactly the error's location.
Instead, using a custom language will produce an error during _runtime_ at some point during execution, where the message may be useful or not depending on the type of error.

Additionally, the code block can be as big and complex as necessary with multiple intermediary computations.
Furthermore, a negative condition may be confusing and not be trivial to write, but in Crystal you would simply use the `#reject` method instead.
The same syntax can also be used for counting, grouping, etc. via the standard library.

Thanks to the topology hierarchical access, the above also works for chains and residues:

```crystal
# select protein chains
struc.chains.select &.residue.any?(&.protein?)
# select only solvent residues
struc.residues.select &.solvent?
# select residues with its CA atom within 5 A of the first CA atom (this is equivalent to "same residue as" or "fillres" in other libraries)
ca = struc.dig('A', 1, "CA")
struc.residues.select { |residue| residue.dig("CA").pos.distance ca.pos < 5 }
```

This may improve performance drastically when selecting chains/residues as it only requires traversing the chains/residues, which will be significantly smaller than the number of atoms.
Most libraries do not offer such functionality, and one often needs to resort to select unique atoms within the desired residues.

### Coordinates manipulation

All coordinates manipulation is done using a `CoordinatesProxy` instance, available for any topology object containing atoms (_i.e._ structure, chain, and residue) via the `#pos` method:

```crystal
# geometric center
struc.pos.center
# center at origin
struc.pos.center_at_origin
# wraps atoms into the primary unit cell
struc.pos.wrap
# rotate about an axis
struc.pos.rotate Chem::Spatial::Vec3[1, 2, 3], 90.degrees
# align coordinates to a reference structure
struc.pos.align_to ref_struc
```

## Benchmark

`chem.cr` is implemented in pure Crystal, making it as fast or even faster than
some C-powered packages.

There is a benchmark at the [pdb-bench](https://github.com/franciscoadasme/pdb-bench) repository that compares `chem.cr` with popular software for computational chemistry.
The benchmark includes the following tests:

- Read and parse PDB files.
- Counting residues matching a condition.
- Calculating distances.
- Calculating the Ramachandran angles.
- Aligning two structures.

Overall, `chem.cr` (orange) comes first in most tests, sometimes over two orders of magnitude faster than the tested software.
Otherwise, it is slightly slower than the faster software, even compared to C/C++ code.

Parsing a large PDB file like `1HTQ` seems to be slow in `chem.cr`, but the implementation may drastically differ between software (e.g. error checking, implicit bond guessing).
Please refer to the table at the [benchmark results](https://github.com/franciscoadasme/pdb-bench#results) for a detailed comparison.

![](https://github.com/franciscoadasme/pdb-bench/raw/master/assets/bench.png)

## Roadmap

### Topology manipulation

- [x] Automatic connectivity detection (includes periodic systems).
- [x] Automatic bond order assignment.
- [x] Residue templates.
  - [x] Custom terminal groups.
- [x] Automatic topology reconstruction based on residue templates.
- [x] Atom wildcards (`"C*"` will select `"C"`, `"CA"`, `"CB"`, etc.).
- [ ] Atom selection language.

### Input and Output

- [x] Automatic file format detection.
- [x] Support for per-file format options (_e.g._ select PDB chain).
- [x] Friendly errors (message with error location).
- [x] Iterator-based IO.
- [ ] Compressed files (.gz and .xz).
- [x] Trajectory support (basic implementation).

#### File formats

- [x] PDB (.pdb, .ent).
- [ ] Macromolecular Crystallographic Information Framework (CIF).
- [ ] MacroMolecular Transmission Format (MMTF).
- [x] Extended XYZ (.xyz).
- [x] Mol/SDF (.mol, .sdf).
- [x] Tripos Mol2 (.mol2).
- [x] PSF (.psf).
- [ ] Maestro (.mae).
- [x] DCD trajectory format (.dcd).
- [x] JDFTx (.ionpos and .lattice).
- [x] VASP's Poscar (POSCAR, CONTCAR).
- [x] DFTB+'s Gen format (.gen).

### Analysis

- [x] Coordinates manipulation.
- [x] Spatial calculations (distance, angle, dihedral, quaternions, affine transformations).
- [x] Periodic boundary conditions (PBC) support (topology-aware wrap and unwrap).
- [x] Secondary structure assignment.
  - [x] DSSP (native implementation).
  - [x] STRIDE (uses external program for now).
  - [x] PSIQUE (own method).
- [x] Nearest neighbor search (via native k-d tree).
- [x] RMSD.
- [x] Structure superposition.
- [ ] Intermolecular interactions (H-bonds, etc.).
- [x] Volumetric data.
- [ ] Parallel processing.

### Other

- [ ] Documentation.
- [ ] Guides.
- [ ] Workflows (handle calculation pipelines).
- [ ] More tests.

## Similar software

There are several libraries providing similar functionality.
Here we list some of them and provide one or more reasons for why we didn't use them. However, each one of them is good in their own right, so please do check them out if `chem.cr` does not work for you.

- [Chemfiles](http://chemfiles.org/) is a library for reading and writing chemistry files written in C++, but can also be used from other languages such as Python.
  It is mainly focused on simulation trajectories and does not provide an object-oriented topology access.
  Also, it does not provide functionality beyond parsing and writing files.
- [OpenBabel](https://openbabel.org/wiki/Main_Page) is a massive C++ library providing support for more than 110 formats.
  Its API is very complex to use.
- [MDTraj](http://mdtraj.org/latest/), [MDAnalysis](http://www.mdanalysis.org/), [cclib](https://cclib.github.io), [pymatgen](https://pymatgen.org), [prody](http://prody.csb.pitt.edu), [Biopython](https://biopython.org) and more are written in Python, which usually means two things.
  First, no type safety makes them sometimes difficult to use if there is not enough documentation (more common than one may think).
  Second, need to deal with C for performance critical code.
- [VMD](http://www.ks.uiuc.edu/Research/vmd/) and [Schrodinger](https://schrodinger.com/) are very popular software for molecular visualization that provide an API in Tcl and/or Python to manipulate molecules.
  However, these usually suffer from poor documentation, and they are difficult to extend functionality.

## Testing

Run the tests with the `crystal spec` command.
Some tests work by compiling small programs, which may be slower to run.
These may be skipped by running:

```console
$ crystal spec --tag='~codegen'
```

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

[1]: https://crystal-lang.org
[2]: https://en.wikipedia.org/wiki/Protein_Data_Bank_(file_format)
[3]: https://crystal-lang.org/install
[4]: https://crystal-lang.org/reference/1.14/syntax_and_semantics/requiring_files.html
