require "spec"
require "../src/chem"

include Chem
include Chem::Spatial

module Spec
  struct CloseExpectation
    def match(actual_value : Enumerable(Vec3)) : Bool
      return false unless @expected_value.size == actual_value.size
      actual_value.zip(@expected_value).all? do |a, b|
        a.close_to? b, @delta
      end
    end

    def match(actual_value : Array(T)) forall T
      if @expected_value.size != actual_value.size
        raise ArgumentError.new "arrays have different sizes"
      end
      actual_value.zip(@expected_value).all? { |a, b| (a - b).abs <= @delta }
    end

    def match(actual_value : Array(Vec3))
      return false unless @expected_value.size == actual_value.size
      actual_value.zip(@expected_value).all? do |a, b|
        a.close_to? b, @delta
      end
    end

    def match(actual_value : Chem::Spatial::Vec3)
      actual_value.close_to? @expected_value, @delta
    end

    def match(actual_value : Chem::Spatial::Quat) : Bool
      return false unless @expected_value.is_a?(Chem::Spatial::Quat)
      actual_value.close_to? @expected_value, @delta
    end

    def match(actual_value : Chem::Spatial::Mat3)
      return false unless @expected_value.is_a?(Chem::Spatial::Mat3)
      actual_value.close_to? @expected_value, @delta
    end

    def match(actual_value : Chem::Spatial::AffineTransform) : Bool
      return false unless @expected_value.is_a?(Chem::Spatial::AffineTransform)
      actual_value.close_to? @expected_value, @delta
    end

    def match(actual_value : Chem::Spatial::Size3) : Bool
      return false unless @expected_value.is_a?(Chem::Spatial::Size3)
      (0..2).all? do |i|
        actual_value[i].close_to?(@expected_value[i], @delta)
      end
    end

    def match(actual_value : Chem::Spatial::Bounds) : Bool
      return false unless @expected_value.is_a?(Chem::Spatial::Bounds)
      actual_value.close_to?(@expected_value, @delta)
    end

    def match(actual_value : Indexable(Number::Primitive)) : Bool
      return false unless @expected_value.is_a?(Indexable) &&
                          @expected_value.size == actual_value.size
      actual_value.zip(@expected_value).all? do |a, b|
        a.close_to?(b, @delta)
      end
    end
  end
end

def fake_structure(*, include_bonds : Bool = true) : Chem::Structure
  structure = Chem::Structure.build do
    title "Asp-Phe Ser"

    chain do
      residue "ASP" do
        atom "N", Vec3[-2.186, 22.128, 79.139]
        atom "CA", Vec3[-0.955, 21.441, 78.711]
        atom "C", Vec3[-0.595, 21.849, 77.252]
        atom "O", Vec3[-1.461, 21.781, 76.374]
        atom "CB", Vec3[-1.316, 19.953, 79.003]
        atom "CG", Vec3[-0.895, 18.952, 77.936]
        atom "OD1", Vec3[-1.281, 17.738, 78.086]
        atom "OD2", Vec3[-0.209, 19.223, 76.945], formal_charge: -1
      end

      residue "PHE" do
        atom "N", Vec3[0.647, 22.313, 76.991]
        atom "CA", Vec3[1.092, 22.731, 75.639]
        atom "C", Vec3[1.006, 21.699, 74.529]
        atom "O", Vec3[0.990, 22.038, 73.319]
        atom "CB", Vec3[2.618, 23.255, 75.696]
        atom "CG", Vec3[2.643, 24.713, 75.877]
        atom "CD1", Vec3[1.790, 25.237, 76.833]
        atom "CD2", Vec3[3.242, 25.569, 74.992]
        atom "CE1", Vec3[1.639, 26.577, 76.996]
        atom "CE2", Vec3[3.100, 26.930, 75.157]
        atom "CZ", Vec3[2.331, 27.435, 76.167]
      end
    end

    chain do
      residue "SER" do
        atom "N", Vec3[7.186, 2.582, 8.445]
        atom "CA", Vec3[6.500, 1.584, 7.565]
        atom "C", Vec3[5.382, 2.313, 6.773]
        atom "O", Vec3[5.213, 2.016, 5.557]
        atom "CB", Vec3[5.908, 0.462, 8.400]
        atom "OG", Vec3[6.990, -0.272, 9.012]
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

# Returns the path for a spec file
def spec_file(filename : String) : String
  path = filename
  ext = File.extname(filename)
  path = File.join ext[1..], path unless ext.blank?
  path = File.join "spec", "data", path
  return path if File.exists?(path)
  path = File.join "spec", "data", filename.downcase, filename
  return path if File.exists?(path)
  File.join "spec", "data", filename
end

# Returns the structure associated with *filename*. The latter is
# expected to be a filename, not a path.
def load_file(filename : String, guess_topology : Bool = false) : Structure
  path = spec_file filename
  case Chem::Format.from_filename(filename)
  when .xyz?    then Chem::Structure.from_xyz(path, guess_topology: guess_topology)
  when .poscar? then Chem::Structure.from_poscar(path, guess_topology: guess_topology)
  when .gen?    then Chem::Structure.from_gen(path, guess_topology: guess_topology)
  else               Chem::Structure.read(path)
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

def make_grid(nx : Int,
              ny : Int,
              nz : Int,
              bounds : Bounds = Bounds[0, 0, 0]) : Grid
  Grid.build({nx, ny, nz}, bounds) do |buffer|
    (nx * ny * nz).times do |i|
      buffer[i] = i.to_f
    end
  end
end

def make_grid(nx : Int,
              ny : Int,
              nz : Int,
              bounds : Bounds = Bounds[0, 0, 0],
              &block : Int32, Int32, Int32 -> Number) : Grid
  Grid.new({nx, ny, nz}, bounds).map_with_loc! do |_, (i, j, k)|
    (yield i, j, k).to_f
  end
end
