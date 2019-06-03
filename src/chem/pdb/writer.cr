module Chem::PDB
  @[IO::FileType(format: PDB, ext: [:ent, :pdb])]
  class Writer < IO::Writer
    PDB_VERSION      = "3.30"
    PDB_VERSION_DATE = Time.new 2011, 7, 13

    def initialize(@io : ::IO, @bonds : Array(Bond)? = nil)
    end

    def <<(structure : Structure) : self
      if expt = structure.experiment
        self << expt
      elsif !structure.title.blank?
        write_title structure.title
      end
      write_pdb_version structure.experiment.try(&.pdb_accession) || ""
      if lattice = structure.lattice
        self << lattice
      end
      structure.each_chain { |chain| self << chain }
      write_bonds
      @io.puts "END".ljust(80)
      self
    end

    private def <<(atom : Atom) : Nil
      @io.printf "%-6s%5d %4s%1s%3s %1s%4d%1s   %8.3f%8.3f%8.3f%6.2f%6.2f%10s%2s%-2s\n",
        (atom.residue.protein? ? "ATOM" : "HETATM"),
        atom.serial,
        atom.name.ljust(3).rjust(4),
        atom.alt_loc,
        atom.residue.name,
        atom.chain.id,
        atom.residue.number,
        atom.residue.insertion_code,
        atom.x,
        atom.y,
        atom.z,
        atom.occupancy,
        atom.temperature_factor,
        nil,
        atom.element.symbol,
        (atom.formal_charge != 0 ? sprintf("%+d", atom.formal_charge).reverse : nil)
    end

    private def <<(chain : Chain) : Nil
      return if chain.n_residues == 0
      last_residue = uninitialized Residue
      chain.each_atom do |atom|
        self << atom
        last_residue = atom.residue
      end
      write_ter last_residue
    end

    private def <<(expt : Protein::Experiment) : Nil
      write_header expt
      write_title expt.title
      write_expt_method expt
      write_expt_citation expt
    end

    private def <<(lattice : Lattice) : Nil
      @io.printf "%-6s%9.3f%9.3f%9.3f%7.2f%7.2f%7.2f %-11s%4s%10s\n",
        "CRYST1",
        lattice.a.size,
        lattice.b.size,
        lattice.c.size,
        lattice.alpha,
        lattice.beta,
        lattice.gamma,
        lattice.space_group || "",
        "",
        ""
    end

    private def write_bonds : Nil
      if bonds = @bonds
        write_bonds bonds
      end
    end

    private def write_bonds(bonds : Array(Bond)) : Nil
      idx_pairs = Array(Tuple(Int32, Int32)).new bonds.size
      bonds.each do |bond|
        bond.order.clamp(1..3).times do
          idx_pairs << {bond.first.serial, bond.second.serial}
          idx_pairs << {bond.second.serial, bond.first.serial}
        end
      end
      idx_pairs.sort!.chunk(&.[0]).each do |i, pairs|
        pairs.each_slice(4, reuse: true) do |slice|
          @io.printf "CONECT%5d", i
          slice.each { |pair| @io.printf "%5d", pair[1] }
          @io.puts
        end
      end
    end

    private def write_expt_citation(expt : Protein::Experiment) : Nil
      @io.printf "%-6s      %-4s   %-61s\n", "JRNL", "DOI", expt.doi
    end

    private def write_expt_method(expt : Protein::Experiment) : Nil
      method = expt.kind.to_s.underscore.upcase.gsub '_', ' '
      method = method.gsub "X RAY", "X-RAY"
      @io.printf "%-6s    %-70s\n", "EXPDTA", method
    end

    private def write_header(expt : Protein::Experiment) : Nil
      @io.printf "%-6s    %-40s%9s   %4s%14s\n",
        "HEADER",
        nil,
        expt.deposition_date.to_s("%d-%^b-%y"),
        expt.pdb_accession.upcase,
        ""
    end

    private def write_pdb_version(pdb_accession : String) : Nil
      @io.printf "%-6s %3d%70s\n", "REMARK", 4, ""
      @io.printf "%-6s %3d %4s COMPLIES WITH FORMAT V. %4s, %9s%25s\n",
        "REMARK",
        4,
        pdb_accession.upcase,
        PDB_VERSION,
        PDB_VERSION_DATE.to_s("%d-%^b-%y"),
        ""
    end

    private def write_ter(residue : Residue) : Nil
      @io.printf "%-6s%5s%6s%3s %1s%4d%1s%53s\n",
        "TER",
        nil,
        nil,
        residue.name,
        residue.chain.id,
        residue.number,
        residue.insertion_code,
        nil
    end

    private def write_title(title : String) : Nil
      title.scan(/.{1,70}( |$)/).each_with_index do |match, i|
        if i > 0
          @io.printf "%-6s  %2d %-69s\n", "TITLE", i + 1, match[0].strip
        else
          @io.printf "%-6s    %-70s\n", "TITLE", match[0].strip
        end
      end
    end
  end
end
