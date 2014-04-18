require_relative 'SAPCall.rb'
require 'clipboard'

class PrettyPrinter
  include SAPCall	
  SYSTEM = "Y:\\60_RUBY\\20_test_sapnwrfc\\DV1.yml"

  def pretty_print(print_string)
  	call("Z_PRETTY_PRINTER",SYSTEM) do |f|    
  		
  		f.C_SOURCE = print_string.map{|s| { "LINE" => s.rstrip }}

  		f.invoke_new

			return f.C_SOURCE[print_string.length..-1].map{|line, index| line["LINE"] }
  	end	
  end
end

if ARGV[0]
	printer = PrettyPrinter.new		
	Clipboard.copy(printer.pretty_print(Clipboard.paste.split(/\n/)).join("\n"))
else
	require_relative 'extend_test_unit.rb'

	class TestPrettyPrint < Test::Unit::TestCase
		def setup
			@printer = PrettyPrinter.new
		end

		def assert_pretty(act,exp)
			assert( @printer.pretty_print(act) == exp )				
		end

		must("Single Line Pretty Print") do
			assert_pretty(["if sy-uname = 'GUENTERC'."],["IF sy-uname = 'GUENTERC'."])	
		end

		must("Multiple Line Pretty Print") do
			assert_pretty(["if sy-uname = 'GUENTERC'.",
										 "check sy-subrc = 0."],
										["IF sy-uname = 'GUENTERC'.",
										 "  CHECK sy-subrc = 0."])
		end
	end
end
