module Chem::IO
  abstract class Builder
    @auto_close_document = false
    @state : State = :start

    property converter : Converter(Spatial::Vector, Spatial::Vector)?

    abstract def initialize(@io : ::IO)

    def convert(coords : Spatial::Vector) : Spatial::Vector
      if converter = @converter
        converter.convert coords
      else
        coords
      end
    end

    def document(&block : ->) : Nil
      start_document
      yield
      end_document
    end

    def newline : Nil
      raw '\n'
    end

    def number(value : Int | Float) : Nil
      raw value
    end

    def number(value : Int, width : Int, alignment : IO::TextAlignment = :right) : Nil
      @io.printf format_string('d', width, alignment), value
    end

    def number(value : Float, width : Int, alignment : IO::TextAlignment = :right) : Nil
      @io.printf format_string('f', width, alignment), value
    end

    def number(value : Float,
               precision : Int,
               scientific : Bool = false,
               width : Int? = nil,
               alignment : IO::TextAlignment = :right) : Nil
      type = scientific ? 'E' : 'f'
      @io.printf format_string(type, width, alignment, precision), value
    end

    def object(&block : ->) : Nil
      start_object
      yield
      end_object
    end

    def raw(value) : Nil
      @io << value
    end

    def string(value : Char | String) : Nil
      raw value
    end

    def string(value : Char | String,
               width : Int,
               alignment : IO::TextAlignment = :left) : Nil
      @io.printf format_string('s', width, alignment), value
    end

    def space : Nil
      @io << ' '
    end

    def space(width : Int) : Nil
      width.times { @io << ' ' }
    end

    protected def document_footer; end

    protected def document_header; end

    protected def object_footer; end

    protected def object_header; end

    private enum State
      End
      Object
      Start
      Document
    end

    private def end_document : Nil
      case @state
      when .document?
        document_footer
        @state = :end
      when .object?
        raise Error.new "Unterminated object"
      else
        raise Error.new "Empty document"
      end
    end

    private def end_object : Nil
      case @state
      when .object?
        object_footer
        @state = :document
        end_document if @auto_close_document
      when .start?
        raise Error.new "Empty document"
      else
        raise Error.new "Uninitialized object"
      end
    end

    private def format_string(type : Char,
                              width : Int?,
                              alignment : IO::TextAlignment,
                              precision : Int? = nil) : String
      String.build do |io|
        io << '%'
        io << '-' if width && alignment.left?
        io << width
        io << '.' << precision unless precision.nil?
        io << type
      end
    end

    private def start_document : Nil
      case @state
      when .start?
        document_header
        @state = :document
      else
        raise Error.new "Document can only be started once"
      end
    end

    private def start_object : Nil
      case @state
      when .start?
        start_document
        @auto_close_document = true
        start_object
      when .document?
        object_header
        @state = :object
      else
        raise Error.new "Unterminated object"
      end
    end
  end

  macro finished
    {% for builder in Builder.subclasses.select(&.annotation(FileType)) %}
      {% format = builder.annotation(FileType)[:format].id.underscore %}

      class ::Chem::Structure
        def to_{{format.id}}(**options) : String
          String.build do |io|
            to_{{format.id}} io, **options
          end
        end

        def to_{{format.id}}(io : ::IO, **options) : Nil
          to_{{format.id}} {{builder}}.new(io, **options)
        end

        def to_{{format.id}}(path : Path | String, **options) : Nil
          File.open path, mode: "w" do |io|
            to_{{format.id}} io, **options
          end
        end
      end
    {% end %}
  end
end
