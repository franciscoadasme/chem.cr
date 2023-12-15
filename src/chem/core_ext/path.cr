struct Path
  # Returns the path by replacing the current extension with *extname*.
  #
  # ```
  # Path["/foo/bar.xyz"].with_ext(".pdb") # => Path["/foo/bar.pdb"]
  # Path["/foo/bar"].with_ext(".xyz")     # => Path["/foo/bar.xyz"]
  # ```
  def with_ext(extname : String) : self
    parent / "#{stem}#{extname}"
  end
end
