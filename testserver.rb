require 'rubygems'
require 'sapnwrfc'

#puts SAPNW::RFC.methods
#server = SAPNW::RFC.rfc_register

SAPNW::Base.config_location = "DX1.yml"
SAPNW::Base.load_config

func = SAPNW::RFC::FunctionDescriptor.new("RFC_REMOTE_PIPE")

func.addParameter(SAPNW::RFC::Export.new(:name => "I_TEST", :len => 20, :type => SAPNW::RFC::CHAR))
func.addParameter(SAPNW::RFC::Import.new(:name => "E_TEST", :len => 20, :type => SAPNW::RFC::CHAR))

func.callback = Proc.new do |fc|
	$stderr.print "#{fc.name} got called with #{fc.I_TEST}\n"
	puts("callback")
	fc.E_TEST = fc.I_TEST

	true
end

server = SAPNW::Base.rfc_register(:trace  => 1,	
								  :tpname => "ProgrammID",
								  :gwhost => "rs190",
								  :gwserv => "sapgw00")

server.installFunction(func)

globalCallBack = Proc.new do |attrib|
	$stderr.print "global got called: #{attrib.inspect}\n"
	true
end

server.accept(60,globalCallBack)