#!/usr/bin/ruby

require 'test/unit'
require 'test/unit/assertions'

require_relative 'SAPCall.rb'

class SAPCallTest < Test::Unit::TestCase
	include SAPCall

	def setup
	  SAP_LOGGER.warn "Current DIR: #{Dir.pwd}\n"
	end

	def test_simple_call
		call("Z_TEST","DV2.yml") do |f,invoke|
			f.I_PAR1 = "Test"

			f.invoke_new
			
			assert(f.E_PAR1 == "Test")
		end
	end
	
	def test_simple_call_with_assert
	  	call("Z_TEST","DV2.yml") do |f,invoke|		    			
		    assert(f.parameters.has_key?("I_PAR1"))
		    assert(f.name == "Z_TEST")

		    assert(f.parameters.has_key?("E_PAR1"))

		    f.I_PAR1 = 'Dies ist ein Test'
			SAP_LOGGER.warn "FunctionCall: #{f.inspect}"
			SAP_LOGGER.warn "FunctionCall I_PAR1: #{f.I_PAR1}/#{f.parameters['I_PAR1'].type}"
			assert(f.I_PAR1 == 'Dies ist ein Test')
			
			f.invoke_new

			SAP_LOGGER.warn "Exporting parameters"
			SAP_LOGGER.warn "#{f.E_PAR1}"
			SAP_LOGGER.warn "#{f.E_PAR1.inspect}"

			assert(f.E_PAR1 == "Dies ist ein Test")		    
		end
	end

	def test_complex_returntype
		call("Z_TEST2","DV2.yml") do |f,invoke|
			assert(f.parameters.has_key?("I_PERNR"))
			assert(f.parameters.has_key?("E_PA0001"))

			f.I_PERNR = "12667"

			f.invoke_new

			f.E_PA0001.each do |k,v|
				SAP_LOGGER.warn "#{k} -> #{v}"
			end
		end
	end

	def test_table_returntype
		call("Z_TEST3","DV2.yml") do |f,invoke|			
			assert(f.parameters.has_key?("I_PERNR"))
			assert(f.parameters.has_key?("ET_PA0001"))

			f.I_PERNR = "12667"

			f.invoke_new

			assert(f.ET_PA0001.length == 2)
			
			f.ET_PA0001.each_with_index do |line, index|
				SAP_LOGGER.warn "\n#{index}"
				line.each do |k, v|
					SAP_LOGGER.warn "#{k} -> #{v}"
				end
			end
		end		
	end

	def test_dv1
		call("RFC_READ_TABLE","DV1.yml") do |f,invoke|
			f.QUERY_TABLE = "ZEHS_MAT_MD_01"

			f.invoke_new

			assert(f.FIELDS.length == 3)
			assert(f.DATA.length == 12)			
		end
	end

	def test_dv1_read_report
		call("RFC_READ_DEVELOPMENT_OBJECT","DV1.yml") do |f,invoke|
			f.PROGRAM = "Z_TEST_CONVERT_TO_RANGE"

			f.invoke_new

			assert(f.QTAB.length == 11)

			f.QTAB.each_with_index do |line, index|
				puts "#{index}: #{line}"
			end
		end
	end

	def test_dx1
		call("ZPM_STANDORT","DX1.yml") do |f|
			f.QUERY_TABLE = "VBAK"

			f.invoke_new

			assert(f.FIELDS == 160)
		end
	end

	def teardown
	end
end