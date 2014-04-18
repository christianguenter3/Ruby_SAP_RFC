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

  def is_method_call?(object)    
    object =~ /(.*)[=|-](.*)>/      
  end

  def get_interface(object,option={})
    def add_data
      if @result[0] =~ /.*\*.*/
        @result.insert(0, "DATA: \n")
      else
        @result[0] = "DATA: " + @result[0].lstrip
      end
    end

    def change_last_char_to_point
      @result[-1] = @result[-1].chop.chop

      if @result[-2] =~ /.*["|\*]/
        @result << "\n."
      else
        @result << "."
      end
    end
 
    def processing(get_interface,get_stub,option={})
      get_interface.call
      add_data
      change_last_char_to_point
      @result << "\n"
      @result << "\n"
      get_stub.call if option.has_key?("WITH_CALL")
    end

    if is_method_call?(object)
      processing( Proc.new{ get_method_interface(object) },
                  Proc.new{ get_method_stub(object) },
                  option)
    else
      processing( Proc.new{ get_fm_interface(object) },
                  Proc.new{ get_fm_stub(object) },
                  option)
    end
    
    @result    
  end

  def get_method_interface(object)
    call("Z_CLASS_IMPORT_METH_INTERFACE",SYSTEM) do |f|
      object =~ /(.*)[=|-]>(.*)/

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
            @result << " #{v.strip}#{' value ' +  line['PARVALUE'].strip if line['PARVALUE'].strip != '' }\,\n".downcase
          when "TYPTYPE"
            if v == "1"
              @result << " TYPE"
            elsif v == "3"
              @result << " TYPE REF TO"
            end
          else
            @result << "#{"*" if line["PAROPTIONL"] == "X" || line["PARVALUE"].strip != ""}      #{v.strip} ".ljust(len + 8).downcase
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
      object =~ /(.*)[=|-]>(.*)/

      f.MTDKEY = { "CLSNAME" => $1,
                   "CPDNAME" => $2 }

      f.invoke_new

      source_processing(f.PATTERNSOURCE)
    end
  end

  def line_processing(line, len)
    line.select{|k,v| k == "PARAMETER" or
                      k =~ /DB/ or
                      k == "TYP" }.each do |k,v|
      case k
        when "DBFIELD"
          @result << "TYPE #{v.strip.downcase},\n" if v.strip != ""
        when "DBSTRUCT"
          @result << "TYPE STANDARD TABLE OF #{v.strip.downcase},\n" if v.strip != ""
        when "TYP"
          @result << "TYPE #{v.strip.downcase { |n|  }},\n" if v.strip != ""
        else
          @result << "#{"*" if line["OPTIONAL"] == "X"}     #{v.strip.downcase} ".ljust(len + 8) + "#{" " if line["OPTIONAL"] == "X"}"
      end
    end
  end

  def source_processing(source)
    source.each do |line|
      line.each do |k,v|
        if v =~ /(["|\*])?(.*)=[^>](.*)/
          left_side    = $2
          right_side ||= $3

          @result << "#{"* " if $1} #{left_side if left_side}= #{ right_side =~ /[0-9]/ ? right_side.strip : left_side.strip} \n".downcase
        elsif v =~ /(")(.*)/
          @result << "*#{$2}\n"
        else
          @result << "#{v.rstrip}\n"
        end
      end
    end
  end
end

if ARGV[0]
  fm_if = FM_Interface.new
  option = {}
  option[ARGV[1]] = true
  result = fm_if.get_interface(ARGV[0].upcase,option)
  Clipboard.copy(result.join(""))
else
  require_relative 'extend_test_unit.rb'

  class TestFM_Interface < Test::Unit::TestCase
    def setup
      @fm_if = FM_Interface.new
      @result = []
    end

    def assert_include(data)
      assert(@result.include?(data))      
    end

    def assert_not_include(data)
      assert(!@result.include?(data))      
    end

    must("Valid result if called with function module") do 
      @result = @fm_if.get_interface("SEOM_CALL_METHOD_PATTERN_NEW",{"WITH_CALL" => true})

      assert_include("DATA: mtdkey              ")
      assert_include("*     enhancement         ")
      assert_include("TYPE swbse_max_line_tab")
      assert_include(".")

      assert_include("     mtdkey                    = mtdkey \n")
      assert_include("* EXCEPTIONS\n")
      assert_include("*     method_not_existing       = 1 \n")
    end

    must("Valid result if called with a bapi function module") do
      @result = @fm_if.get_interface("BAPI_ALM_NOTIF_CREATE",{"WITH_CALL" => true})
      
      assert_include("DATA: \n")
      assert_include("*     external_number                 ")
      assert_include("TYPE bapi2080_nothdre-notif_no,\n")
      assert_include("CALL FUNCTION 'BAPI_ALM_NOTIF_CREATE'\n")
    end

    must("Valid result if called with a static method") do
      @result = @fm_if.get_interface("cl_gui_frontend_services=>directory_browse",{"WITH_CALL" => true})
      
      
      assert_include("DATA: \n")
      assert_include("      selected_folder  ")
      assert_include(" TYPE")
      assert_include(" string")
      assert_include(".")
      assert_include("     selected_folder      = selected_folder \n")
      assert_include("*      not_supported_by_gui = 3 \n")
      assert_include("CL_GUI_FRONTEND_SERVICES=>DIRECTORY_BROWSE(\n")
      assert_include("       ).\n")
    end

    must("valid declarations with default parameters") do
      @result = @fm_if.get_interface("cl_gui_frontend_services=>gui_download",{"WITH_CALL" => true})
                      
      assert_include("*      write_field_separator     ")
      assert_include(" TYPE")
      assert_include(" char01 value space,\n")
      assert_include("*      write_field_separator     = write_field_separator \n")
    end

    must("valid declarations without call") do 
      @result = @fm_if.get_interface("BAPI_ALM_NOTIF_CREATE",{})

      assert_not_include("CALL FUNCTION 'BAPI_ALM_NOTIF_CREATE'\n")
    end
  end
end

