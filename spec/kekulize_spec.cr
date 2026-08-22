require "./spec_helper"

describe "Chem.kekulize" do
  it_kekulizes "indole and benzene", "783.mol2", %w(
    C1=C2 C2-C3 C3=C4 C4-C5 C5=C6 C1-C6
    C4-N3 N3-C8 CN4=C8
    C1'=C2' C2'-C3' C3'=C4' C4'-C5' C5'=C6' C1'-C6'
    C1B-C2B C2B=C3B C3B-C4B C4B=C5B C5B-C6B C1B=C6B
  )

  it_kekulizes "quinazoline and pyrazole", "8FX.mol2", %w(
    C1=C2 C2-C3 C3=C4 C4-C20 C19-C20 C1-C19
    C18=C19 N7-C18 C17=N7 N6-C17 N6=C20
    C5-C6 C6=C7 C7-N2 N2-N3 C5=N3
  )

  it_kekulizes "napthalene", "naphthalene.mol2", %w(
    C1-C2 C2=C3 C3-C4 C4=C9 C9-C10 C1=C10
    C4-C5 C5=C6 C6-C7 C7=C8 C8-C9
  )

  it_kekulizes "three fused rings", "tac.mol2", %w(
    C4=C6 C4-C7 C7=C8 C8-C9 N1=C9
    C8-C10 C9-C11 C10=C12 C11=C13 C12-C13
  )

  it_kekulizes "four fused rings", "ac1.mol2", %w(
    C1=C2 C2-C4 C4-C6 C6-C7 C3=C7 C1-C3
    C2-C8 C8=C9 C5-C9
    C3-C10 C10=C14 C11-C14 C5=C11
    C4=C12 C12-C15 C15=C16 C13-C16 C6=C13
  )

  it_kekulizes "rings joined by a simple ring", "flu.mol2", %w(
    C1=C2 C2-C7 C7=C13 C11-C13 C6=C11 C1-C6
    C6-C12 C12=C14 C8-C14 C3=C8
    C4-C5 C5=C10 C10-C16 C15=C16 C9-C15 C4=C9
  )
end

private def it_kekulizes(desc, path, bonds_spec, file = __FILE__, line = __LINE__)
  it "kekulizes #{desc}", file, line do
    structure = load_file(path)
    bonds = structure.bonds.map &.to_s
    bonds_spec.each do |bond|
      bonds.should contain bond
    end
  end
end
