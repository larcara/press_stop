
require 'net/http'
require_relative "./lib/xmlrpc/client"

#API_KEY="TTU8rKwDFEN4uL4iuyO9wlNDTJE78kXR"
API_KEY='bL5fwQZNDFdHkIR1hjxYCFIBrVRV78Hw'



class AtacProxy
	attr_accessor :token, :service_paline , :service_percorso
	def initialize(_token="")
		XMLRPC::Config.module_eval do
			    remove_const :ENABLE_NIL_PARSER
			    const_set :ENABLE_NIL_PARSER, true
		end
		autenticazione    =  XMLRPC::Client.new("muovi.roma.it", "/ws/xml/autenticazione/1", 80)
		@service_paline   =  XMLRPC::Client.new("muovi.roma.it", "/ws/xml/paline/7", 80)	
		@service_percorso =  XMLRPC::Client.new("muovi.roma.it", "/ws/xml/percorso/2", 80)
		
		if _token.blank?
			begin
			puts "Creating new client"
			@token = autenticazione.call("autenticazione.Accedi", API_KEY, '')
			
		rescue XMLRPC::FaultException => e
		  puts "Error:"
		  puts e.faultCode
		  puts e.faultString
		end		
		else
		@token=_token
		end
	end

	def search_path(from, to )
	  #https://bitbucket.org/agenziamobilita/muoversi-a-roma/wiki/percorso.Cerca
	  path = @service_percorso.call("percorso.Cerca", @token,  from, to, {mezzo: 1, piedi: 0, bus:true, metro:false, ferro:false, carpooling:false, max_distanza_bici:0 },Time.now.strftime("%Y-%m-%d %H:%M:%S"), "IT")
	end
	def get_stops(percorso, mezzo="", data="" )
		#puts ["paline.Percorso", @token,  percorso, mezzo, data, "IT"]
		begin
      stops = @service_paline.call("paline.Percorso", @token,  percorso.to_s, mezzo, data, "IT")
		  return stops["risposta"]
    rescue  XMLRPC::FaultException => e
      puts "Error:"
      puts e.faultCode
      puts e.faultString
      return nil
    end
	end
	def get_linee(palina)
       begin
	   	linee = @service_paline.call("paline.PalinaLinee", @token,  palina,  "IT")
	   	return linee["risposta"]
	   rescue  XMLRPC::FaultException => e
		  puts "Error:"
		  puts e.faultCode
		  puts e.faultString
	   linee = []
           end
  end
  def previsioni(palina)
       begin
         previsioni = @service_paline.call("paline.Previsioni", @token,  palina,  "IT")
	   return previsioni["risposta"]
	   rescue  XMLRPC::FaultException => e
		  puts "Error:"
		  puts e.faultCode
		  puts e.faultString
	   linee = []
           end
	end
	def get_percorsi(linea)
		puts "get perscorsi per #{linea}"
	   begin
		linee = @service_paline.call("paline.Percorsi", @token,  linea,  "IT")
		return linee["risposta"]["percorsi"].map{|x| [x["id_percorso"], x["capolinea"]]}
	   rescue  XMLRPC::FaultException => e
		  puts "Error:"
		  puts e.faultCode
		  puts e.faultString
	   	linee = []
           end
		
	end

	def smart_search(query)
		result = @service_paline.call("paline.SmartSearch", @token, query)
	end
end
