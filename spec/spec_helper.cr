require "spec"
require "../src/chem"

alias Atom = Chem::Atom
alias AtomView = Chem::AtomView
alias Basis = Chem::Spatial::Basis
alias Bounds = Chem::Spatial::Bounds
alias Chain = Chem::Chain
alias Constraint = Chem::Constraint
alias Element = Chem::Element
alias Grid = Chem::Spatial::Grid
alias Lattice = Chem::Lattice
alias M = Chem::Linalg::Matrix
alias PBC = Chem::Spatial::PBC
alias PDB = Chem::PDB
alias ParseException = Chem::ParseException
alias PeriodicTable = Chem::PeriodicTable
alias Q = Chem::Spatial::Quaternion
alias S = Chem::Spatial::Size
alias Structure = Chem::Structure
alias Topology = Chem::Topology
alias Tf = Chem::Spatial::AffineTransform
alias V = Chem::Spatial::Vector
alias Vector = Chem::Spatial::Vector

enum TopologyLevel
  None
  Templates
  Bonds
  Guess
  Renumber
end

module Spec
  struct CloseExpectation
    def match(actual_value : Enumerable(Vector)) : Bool
      return false unless @expected_value.size == actual_value.size
      actual_value.zip(@expected_value).all? do |a, b|
        {(a.x - b.x).abs, (a.y - b.y).abs, (a.z - b.z).abs}.all? do |value|
          value <= @delta
        end
      end
    end

    def match(actual_value : Array(T)) forall T
      if @expected_value.size != actual_value.size
        raise ArgumentError.new "arrays have different sizes"
      end
      actual_value.zip(@expected_value).all? { |a, b| (a - b).abs <= @delta }
    end

    def match(actual_value : Array(Chem::Spatial::Vector))
      return false unless @expected_value.size == actual_value.size
      actual_value.zip(@expected_value).all? do |a, b|
        dvec = (a - b).abs
        dvec.x <= @delta && dvec.y <= @delta && dvec.z <= @delta
      end
    end

    def match(actual_value : Chem::Spatial::Vector)
      [(actual_value.x - @expected_value.x).abs,
       (actual_value.y - @expected_value.y).abs,
       (actual_value.z - @expected_value.z).abs].all? do |value|
        value <= @delta
      end
    end

    def match(actual_value : Chem::Spatial::Quaternion) : Bool
      (0..3).all? { |i| (actual_value[i] - @expected_value[i]).abs <= @delta }
    end

    def match(actual_value : Chem::Linalg::Matrix) : Bool
      return false if actual_value.dim != @expected_value.dim
      actual_value.each_with_index.all? do |value, i, j|
        (value - @expected_value.unsafe_fetch(i, j)).abs <= @delta
      end
    end

    def match(actual_value : Chem::Spatial::AffineTransform) : Bool
      actual_value.@mat.each_with_index.all? do |value, i, j|
        (value - @expected_value.@mat.unsafe_fetch(i, j)).abs <= @delta
      end
    end

    def match(actual_value : Chem::Spatial::Size) : Bool
      (actual_value.x - @expected_value.x).abs <= @delta &&
        (actual_value.y - @expected_value.y).abs <= @delta &&
        (actual_value.z - @expected_value.z).abs <= @delta
    end

    def match(actual_value : Chem::Spatial::Bounds) : Bool
      (actual_value.origin - @expected_value.origin).abs.size <= @delta &&
        (actual_value.i - @expected_value.i).abs.size <= @delta &&
        (actual_value.j - @expected_value.j).abs.size <= @delta &&
        (actual_value.k - @expected_value.k).abs.size <= @delta
    end
  end
end

def fake_structure(*, include_bonds : Bool = true) : Chem::Structure
  structure = Chem::Structure.build do
    title "Asp-Phe Ser"

    chain do
      residue "ASP" do
        atom "N", V[-2.186, 22.128, 79.139]
        atom "CA", V[-0.955, 21.441, 78.711]
        atom "C", V[-0.595, 21.849, 77.252]
        atom "O", V[-1.461, 21.781, 76.374]
        atom "CB", V[-1.316, 19.953, 79.003]
        atom "CG", V[-0.895, 18.952, 77.936]
        atom "OD1", V[-1.281, 17.738, 78.086]
        atom "OD2", V[-0.209, 19.223, 76.945], formal_charge: -1
      end

      residue "PHE" do
        atom "N", V[0.647, 22.313, 76.991]
        atom "CA", V[1.092, 22.731, 75.639]
        atom "C", V[1.006, 21.699, 74.529]
        atom "O", V[0.990, 22.038, 73.319]
        atom "CB", V[2.618, 23.255, 75.696]
        atom "CG", V[2.643, 24.713, 75.877]
        atom "CD1", V[1.790, 25.237, 76.833]
        atom "CD2", V[3.242, 25.569, 74.992]
        atom "CE1", V[1.639, 26.577, 76.996]
        atom "CE2", V[3.100, 26.930, 75.157]
        atom "CZ", V[2.331, 27.435, 76.167]
      end
    end

    chain do
      residue "SER" do
        atom "N", V[7.186, 2.582, 8.445]
        atom "CA", V[6.500, 1.584, 7.565]
        atom "C", V[5.382, 2.313, 6.773]
        atom "O", V[5.213, 2.016, 5.557]
        atom "CB", V[5.908, 0.462, 8.400]
        atom "OG", V[6.990, -0.272, 9.012]
      end
    end
  end
  unless include_bonds
    structure.each_atom do |atom|
      atom.bonded_atoms.each do |other|
        atom.bonds.delete other
      end
    end
  end
  structure
end

def load_file(path : String, guess_topology : Bool = false) : Structure
  path = File.join File.extname(path)[1..], path unless File.extname(path).blank?
  path = File.join "spec", "data", path
  case Chem::Format.from_filename(path)
  when .xyz?    then Chem::Structure.from_xyz(path, guess_topology: guess_topology)
  when .poscar? then Chem::Structure.from_poscar(path, guess_topology: guess_topology)
  when .gen?    then Chem::Structure.from_gen(path, guess_topology: guess_topology)
  else               Chem::Structure.read(path)
  end
end

def load_hlxparams_data
  {radius: [] of Float64, theta: [] of Float64, zeta: [] of Float64}.tap do |datasets|
    File.each_line("spec/data/spatial/hlxparams.txt") do |line|
      next if line.blank?
      values = line.split.map &.to_f
      datasets[:zeta] << values[0]
      datasets[:theta] << values[1]
      datasets[:radius] << values[2]
    end
  end
end

def make_grid(nx : Int,
              ny : Int,
              nz : Int,
              bounds : Bounds = Bounds.zero) : Grid
  Grid.build({nx, ny, nz}, bounds) do |buffer|
    (nx * ny * nz).times do |i|
      buffer[i] = i.to_f
    end
  end
end

def make_grid(nx : Int,
              ny : Int,
              nz : Int,
              bounds : Bounds = Bounds.zero,
              &block : Int32, Int32, Int32 -> Number) : Grid
  Grid.new({nx, ny, nz}, bounds).map_with_loc! do |_, (i, j, k)|
    (yield i, j, k).to_f
  end
end

macro enum_cast(decl)
  def {{decl.var}}(name : {{decl.type}}) : {{decl.type}}
    name
  end
end

enum_cast sec : Chem::Protein::SecondaryStructure
enum_cast sectype : Chem::Protein::SecondaryStructureType

# Asserts that *code* compiles successfully.
def assert_code(code : String, file = __FILE__, line = __LINE__) : Nil
  success, output = compile_code code
  fail "Code failed with error:\n\n#{output}", file, line unless success
end

# Asserts that compiling *code* produces an error containing *message*.
def assert_error(code : String, message : String, file = __FILE__, line = __LINE__) : Nil
  success, output = compile_code code
  if success
    fail "Expected an error but the code compiled successfully", file, line
  elsif actual_message = output.lines.select(/^Error: /).first?
    actual_message = actual_message.gsub("Error: ", "")
    if actual_message != message
      fail "Expected: #{message}\n     got: #{actual_message}", file, line
    end
  else
    fail "Code failed with unrecognized error:\n\n#{output}", file, line
  end
end

# Compile the given *code*.
private def compile_code(code : String) : {Bool, String}
  tempfile = File.tempfile do |f|
    root = Path.new Path.new(__DIR__).parts.take_while(&.!=("spec"))
    path = root.join("src", "chem").relative_to f.path
    f.puts "require #{path.to_s.inspect}"
    f.puts code
  end
  buffer = IO::Memory.new
  args = ["run", "--no-color", "--no-codegen", tempfile.path]
  result = Process.run("crystal", args, error: buffer)
  {result.success?, buffer.to_s.strip}
ensure
  buffer.try &.close
  tempfile.try &.delete
end
