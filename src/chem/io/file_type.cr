module Chem::IO
  # Marks a class to be associated with a file format.
  #
  # An annotated class must either read or write an instance of the
  # *encoded type* from or to an IO following the specification of the
  # associated *file format*. The ability of a class to read or write is
  # dictated by whether it includes the `Reader` or `Writer` modules,
  # respectively.
  #
  # This annotation accepts the following named arguments:
  #
  # - **encoded** (required): name (unquoted) that resolves into a valid
  #   type
  # - **format** (required): file format (in camel case and unquoted)
  # - **ext**: an array of extensions (without leading dot)
  # - **names**: an array of file names. File names can include
  #   wildcards (*) to denote either prefix (e.g., "Foo*"), suffix
  #   (e.g., "*Bar"), or both (e.g., "*Baz*")
  #
  # The `FileFormat` enum is populated based on the information of this
  # annotation, where extensions and file names are associated with the
  # corresponding file format. It is also used to generate read
  # (`#from_*`) and write (`#to_*`) methods for the encoded types when
  # appropiate.
  #
  # ```
  # alias Point3d = Tuple(Float64, Float64, Float64)
  # record Frame, coords : Array(Point3d)
  #
  # @[FileType(format: XYZ, encoded: Frame, ext: %w(.xyz))]
  # class FrameReader
  #   include IO::Reader(Frame)
  #
  #   def read : Frame
  #     n = @io.gets.to_i
  #     title = @io.gets
  #     coords = Array(Point3d).new(n) do
  #       x, y, z = @io.gets.split[1..].map(&.to_i)
  #       Point3d.new(x, y, z)
  #     end
  #     Frame.new title, coords
  #   end
  # end
  #
  # FileFormat::XYZ                # => XYZ
  # FileFormat.from_ext("foo.xyz") # => XYZ
  #
  # io = IO::Memory.new <<-EOS
  #   9
  #   Three waters
  #   O   2.336   3.448   7.781
  #   H   1.446   3.485   7.315
  #   H   2.977   2.940   7.234
  #   O  11.776  11.590   8.510
  #   H  12.756  11.588   8.379
  #   H  11.395  11.031   7.787
  #   O   6.015  11.234   7.771
  #   H   6.440  12.040   7.394
  #   H   6.738  10.850   8.321
  #   EOS
  #
  # frame = Frame.from_xyz(io)
  # frame.coords.size # => 9
  # frame.coords[0]   # => {2.336, 3.448, 7.781}
  # ```
  annotation FileType; end

  macro finished
    {% readers = Reader.includers.select &.annotation(FileType) %}
    {% writers = Writer.all_subclasses.select &.annotation(FileType) %}
    {% types = readers + writers %}
    {% file_types = types.map &.annotation(IO::FileType) %}

    # check missing annotation arguments
    {% format_by_ext = {} of String => MacroId %}
    {% format_by_name = {} of String => MacroId %}
    {% type_by_ext = {} of String => MacroId %}
    {% type_by_name = {} of String => MacroId %}
    {% for t in types %}
      {% ann = t.annotation(FileType) %}

      {% type = (type = ann[:encoded]) && type.resolve? %}
      {% raise "`encoded` is missing in FileType annotation for #{t}" unless type %}

      {% format = ann[:format].id %}
      {% raise "`format` is missing in FileType annotation for #{t}" unless format %}
      
      {% if extnames = ann[:ext] %}
        {% for ext in extnames %}
          {% if (other = format_by_ext[ext]) && other != format %}
            {% raise ".#{ext.id} extension declared in FileType annotation for #{t} " \
                     "is already associated with file format #{other} " \
                     "via #{type_by_ext[ext]}" %}
          {% end %}
          {% format_by_ext[ext] = format %}
          {% type_by_ext[ext] = t %}
        {% end %}
      {% elsif names = ann[:names] %}
        {% for name in names %}
          {% key = name.tr("*", "").camelcase.underscore %}
          {% if (other = format_by_name[key]) && other != format %}
            {% raise "Filename #{name} declared in FileType annotation for #{t} " \
                     "is already associated with file format #{other} " \
                     "via #{type_by_name[name]}" %}
          {% end %}
          {% format_by_name[key] = format %}
          {% type_by_name[key] = t %}
        {% end %}
      {% else %}
        {% raise "`ext` and `names` are missing in FileType annotation for #{t}" %}
      {% end %}
    {% end %}

    # check duplicate file formats
    {% file_formats = file_types.map(&.[:format].id).uniq.sort %}
    {% for format in file_formats %}
      {% for ary in [readers, writers] %}
        {% ary = ary.select &.annotation(IO::FileType)[:format].id.==(format) %}
        {% if ary.size > 1 %}
          {% raise "#{format} file format in FileType annotation for #{t} " \
                   "is already associated with #{ary[0]}" %}
        {% end %}
      {% end %}
    {% end %}
  end
end
