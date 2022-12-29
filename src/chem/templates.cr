require "./templates/*"

module Chem::Templates
  # Registers an aliases to a known residue template into the _global
  # registry_. Refer to the `Registry` documentation and
  # `Registry#alias` for details.
  def self.alias(new_name : String, to existing_name : String) : Nil
    Chem::Templates::Registry.default.alias new_name, existing_name
  end

  # Loads and registers the residue template(s) from a structure file or
  # YAML file into the _global registry_.
  #
  # Refer to the `Registry` documentation and `Registry#load` for more
  # information.
  def self.load(filepath : Path | String) : Nil
    Chem::Templates::Registry.default.load filepath
  end

  # Parses and registers the residue templates encoded in the given YAML
  # content into the _global registry_. Refer to the `Registry`
  # documentation and `Registry#parse` for details.
  def self.parse(filepath : String) : Nil
    Chem::Templates::Registry.default.parse filepath
  end

  # Creates and registers a residue template from a structure into the
  # _global registry_. Refer to the `Registry` documentation and
  # `Registry#register` for details.
  def self.register(structure : Structure) : Nil
    Chem::Templates::Registry.default.register structure
  end
end
