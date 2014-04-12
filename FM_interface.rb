require_relative 'SAPCall.rb'

require 'clipboard'

class FM_Interface 
	include SAPCall

	SYSTEM = "Y:\\60_RUBY\\20_test_sapnwrfc\\DV1.yml"		

	def initialize		
		@result = []
	end

	def max_len(f)
		len = 0

		def len(line,len)
			line.select{|k,v| k == "PARAMETER" }.each do |k,v|
				len = v.strip.length if v.strip.length > len
			end			
			len
		end

		f.IMPORT_PARAMETER.each do |line|
			len = len(line,len)
		end	

		f.EXPORT_PARAMETER.each do |line|
			len = len(line,len)
		end	

		f.CHANGING_PARAMETER.each do |line|
			len = len(line,len)
		end	

		f.TABLES_PARAMETER.each do |line|
			len = len(line,len)
		end	

		len
	end

	def line_processing(line, len)
		line.select{|k,v| k == "PARAMETER" or 
						  k =~ /DB/ or
						  k == "TYP"  }.each do |k,v|
			case k
			  when "DBFIELD"
			 	@result << "TYPE #{v.strip.downcase},\n" if v.strip != ""
			  when "DBSTRUCT"
			 	@result << "TYPE STANDARD TABLE OF #{v.strip.downcase},\n" if v.strip != ""
			  when "TYP"
			 	@result << "TYPE #{v.strip.downcase { |n|  }},\n" if v.strip != ""
			else				
				@result << "      #{v.strip.downcase} ".ljust(len + 7)
			end 
		end
	end

	def get_interface(object)		
		def add_data
			@result[0] = "DATA: " + @result[0].lstrip
		end

		def change_last_char_to_point
			@result[@result.length - 1] = @result[@result.length - 1].chop.chop
			if @result[@result.length - 1] =~ /["|\*]/
				@result << "\n."				
			else
				@result << "."
			end
		end

		if object =~ /=>/
			get_method_interface(object)
			add_data
			change_last_char_to_point
			@result << "\n"
			@result << "\n"
			get_method_stub(object)
		else
			get_fm_interface(object)
			add_data
			change_last_char_to_point
			@result << "\n"
			@result << "\n"
			get_fm_stub(object)
		end			

		Clipboard.copy(@result.join(""))
	end

	def get_method_interface(object)
		call("Z_CLASS_IMPORT_METH_INTERFACE",SYSTEM) do |f|
			object =~ /(.*)=>(.*)/

			f.I_CLASS = $1
			f.I_METHOD = $2

			f.invoke_new

			len = 0

			f.ET_PARAMETERS.each do |line|				
				line.select{|k,v| k == "SCONAME"}.each do |k,v|
					len = v.strip.length if v.strip.length > len
				end
			end			

			f.ET_PARAMETERS.each do |line|				
				line.select{|k,v| k == "SCONAME" || k == "TYPE" || k == "TYPTYPE"}.each do |k,v|
					case k
						when "TYPE"													
							@result << " #{v.strip},\n".downcase
						when "TYPTYPE"
							if v == "1"
								@result << " TYPE"
							elsif v == "3"
								@result << " TYPE REF TO"	
							end	
						else
							@result << "      #{v.strip} ".ljust(len + 7).downcase
					end					
				end
			end
		end
	end

	def get_fm_interface(function_module)
		call("FUNCTION_IMPORT_INTERFACE",SYSTEM) do |f|
			f.FUNCNAME = function_module

			f.invoke_new

			len = max_len(f)
			
			f.IMPORT_PARAMETER.each do |line|
				line_processing(line,len)
			end

			f.EXPORT_PARAMETER.each do |line|
				line_processing(line,len)
			end

			f.CHANGING_PARAMETER.each do |line|
				line_processing(line,len)
			end

			f.TABLES_PARAMETER.each do |line|
				line_processing(line,len)
			end			
		end		
	end

	def get_fm_stub(function_module)
		call("Z_FUNCTION_STUB_GENERATE",SYSTEM) do |f|
			f.FUNCNAME = function_module

			f.invoke_new

			source_processing(f.SOURCE)			
		end
	end

	def get_method_stub(object)
		call("Z_METHOD_STUB_GENERATE",SYSTEM) do |f|			
			object =~ /(.*)=>(.*)/

			f.MTDKEY = { "CLSNAME" => $1,
						 "CPDNAME" => $2 }

			f.invoke_new

			source_processing(f.PATTERNSOURCE)
		end
	end

	def source_processing(source)
		source.each do |line|
			line.each do |k,v|
				if v =~ /(["|\*])?(.*)=[^>](.*)/
					@result << "#{"*" if $1} #{$2 if $2}= #{$3.strip} \n".downcase
				elsif v =~ /(")(.*)/
					@result << "*#{$2}\n"
				else
					@result << "#{v}\n"
				end
			end				
		end
	end
end

fm_if = FM_Interface.new
fm_if.get_interface(ARGV[0].upcase)                                            

