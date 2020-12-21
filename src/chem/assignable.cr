# The `Assignable` mixin provides a convenience way to declare arguments
# that are needed for instantiation. This is helpful to avoid repeating
# the arguments that are needed by one or more superclasses in the
# `initialize` method of every subclass.
#
# Instantiation arguments are declared by using the `needs` macro, which
# registers the arguments and define getters.
#
# The declared arguments are then used to define an `initialize` method.
# If the type of an argument is nilable and no default value is given,
# it will default to `nil`. The `generate_initializer` macro may be
# overwritten to customize the `initialize` method with additional
# arguments.
#
# NOTE: the argument order may change in the `initialize` method as
# nilable and arguments with a default value are written last. To avoid
# confusion, make sure to always list the arguments in the same order as
# you would write them in an `initialize` method.
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
module Assignable
  # Declares a required argument for an instance of the type to be
  # initialized.
  #
  # It expects a type declaration, which is used to declare an instance
  # variable and getter with the same name. If the type of the argument
  # is `Bool`, it will generate a question method (ending with '?')
  # instead.
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
    {% ASSIGNABLES[@type] = [] of TypeDeclaraction unless ASSIGNABLES[@type] %}
    {% ASSIGNABLES[@type] << decl %}

    def {{decl.var}}{% if decl.type.resolve == Bool %}?{% end %}
      @{{decl.var}}
    end
  end

  # :nodoc:
  ASSIGNABLES = {} of Nil => Nil

  macro included
    setup_initializer_hook
  end

  # Defines an `initialize` method based on the declared instantiation
  # arguments. This may be overwritten by including types to customize
  # the `initialize` method with additional arguments.
  macro generate_initializer
    {% args = (ASSIGNABLES[@type] || [] of TypeDeclaration).sort_by do |decl|
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
      setup_initializer_hook
    end
  end
end
