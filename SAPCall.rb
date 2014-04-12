
require 'rubygems'
require 'sapnwrfc'

class SAPNW::RFC::FunctionCall
	def invoke_new
		begin
		  invoke
		rescue SAPNW::RFC::FunctionCallException => e
		  SAP_LOGGER.warn "FunctionCallException: #{e.error.inspect}\n"
		  raise "gone"
		end
	end	
end	

module SAPCall
	def get_conn(system_yml)
		if FileTest.exists?(system_yml)
			SAPNW::Base.config_location = system_yml
			SAPNW::Base.load_config
			SAPNW::Base::rfc_connect
		else
			raise "no System"
		end		
	end

	def call(function_module, system_yml)
		begin
			connection 			= get_conn(system_yml)					    	
	    	function_descriptor = connection.discover(function_module)		    	
	    	function_call  		= function_descriptor .new_function_call
			
			yield function_call
			
			connection.close
		rescue SAPNW::RFC::ConnectionException => e
			SAP_LOGGER.warn "ConnectionExcepion ERROR: #{e.inspect} - #{e.error.inspect}\n"	
		end		
		GC.start
	end
end