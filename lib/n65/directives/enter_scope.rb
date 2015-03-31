require_relative '../instruction_base'

module N65


  ####
  ##  This directive to include bytes
  class EnterScope < InstructionBase

    ####
    ##  Try to parse an incbin directive
    def self.parse(line)
      ##  Anonymous scope
      match_data = line.match(/^\.scope$/)
      unless match_data.nil?
        return EnterScope.new
      end

      ##  Named scope
      match_data = line.match(/^\.scope\s+([a-zA-Z][a-zA-Z0-9_]+)$/)
      return nil if match_data.nil?
      EnterScope.new(match_data[1])
    end


    ####
    ##  Initialize with filename
    def initialize(name = nil)
      @name = name
    end


    ####
    ##  Execute on the assembler, also create a symbol referring to 
    ##  the current pc which contains a hyphen, and is impossible for
    ##  the user to create.  This makes a scope simultaneously act as
    ##  a label to the current PC.  If someone tries to use a scope
    ##  name as a label, it can return the address when the scope opened.
    def exec(assembler)
      assembler.symbol_table.enter_scope(@name)
      unless @name.nil?
        assembler.symbol_table.define_symbol("-#{@name}", assembler.program_counter)
      end
    end


    ####
    ##  Display
    def to_s
      ".scope #{@name}"
    end

  end

end