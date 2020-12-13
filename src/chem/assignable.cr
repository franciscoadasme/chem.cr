module Assignable
  # Declares a required argument for an instance of the type to be
  # initialized.
  #
  # It expects a type declaration, which is used to declare an instance
  # variable and getter with the same name. If the type of the argument
  # is `Bool`, it will generate a question method (ending with '?')
  # instead. If the type of the argument is nilable and no default value
  # is given, it will default to `nil`.
  #
  # It also generates an `initialize` method based on the declared type
  # declarations.
  #
  # **NOTE**: the argument order may change in the `initialize` method
  # as nilable and arguments with a default value are written last. To
  # avoid confusion, make sure to always list the arguments in the same
  # order as you would write them in an `initialize` method.
  #
  # ```crystal
  # struct Foo
  #   include Assignable
  #
  #   needs bar : Int32
  #   needs baz : String?
  #   needs active : Bool = true
  # end
  #
  # foo = Foo.new # fails to compile since bar is required
  #
  # foo = Foo.new 0
  # foo.bar     # => 0
  # foo.baz     # => nil
  # foo.active? # => true
  #
  # foo = Foo.new 101, "none", active: false
  # foo.bar     # => 101
  # foo.baz     # => "none"
  # foo.active? # => false
  # ```
  macro needs(decl)
    {% unless decl.is_a?(TypeDeclaration) %}
      {% raise "'needs' expects a type declaration like 'name : String', " \
               "got: '#{decl}' in #{@type}" %}
    {% end %}
    {% if decl.var.stringify.ends_with?("?") %}
      {% raise "Don't use '?' with 'needs', got '#{decl}' in #{@type}. " \
               "A question method is generated if the type is Bool" %}
    {% end %}
    {% if decl.var.stringify.starts_with?("@") %}
      {% raise "Don't use '@' with 'needs', got '#{decl}' in #{@type}" %}
    {% end %}
    {% ASSIGNS << decl %}
    
    def {{decl.var}}{% if decl.type.resolve == Bool %}?{% end %}
      @{{decl.var}}
    end
  end

  macro included
    ASSIGNS = [] of Nil
    
    setup_initializer_hook
  end

  private macro generate_initializer
    {% args = ASSIGNS.sort_by do |decl|
         has_explicit_value =
           decl.type.is_a?(Metaclass) ||
             decl.type.types.map(&.id).includes?(Nil.id) ||
             decl.value ||
             decl.value == nil ||
             decl.value == false
         has_explicit_value ? 1 : 0
       end %}

    def initialize(
      {% for decl in args %}
        {% nilable = decl.value.is_a?(Nop) && decl.type.resolve.nilable? %}
        @{{decl}}{% if nilable %} = nil{% end %},
      {% end %}
    )
    end
  end

  private macro setup_initializer_hook
    macro finished
      {% unless @type.module? || @type.abstract? %}
        generate_initializer
      {% end %}
    end

    macro included
      ASSIGNS = [] of Nil

      setup_initializer_hook
    end
  end
end
