require "sinatra"
require "sinatra/reloader" if development?
require_relative "./lib/xmlrpc/client"

#API_KEY="TTU8rKwDFEN4uL4iuyO9wlNDTJE78kXR"
API_KEY='bL5fwQZNDFdHkIR1hjxYCFIBrVRV78Hw'

class AtacProxy
	attr_accessor :token
	def initialize(_token)
		return _token unless _token==nil
		begin
			server = XMLRPC::Client.new("muovi.roma.it", "/ws/xml/autenticazione/1", 80)
			server.http_header_extra = {"Content-Type" => "text/xml"}
			@token = server.call("autenticazione.Accedi", API_KEY, '')
			return @token 
		rescue XMLRPC::FaultException => e
		  puts "Error:"
		  puts e.faultCode
		  puts e.faultString
		end		
	end

	def search_path(from, to )
	  #https://bitbucket.org/agenziamobilita/muoversi-a-roma/wiki/percorso.Cerca
	  begin
			XMLRPC::Config.module_eval do
			    remove_const :ENABLE_NIL_PARSER
			    const_set :ENABLE_NIL_PARSER, true
			end
			server = XMLRPC::Client.new("muovi.roma.it", "/ws/xml/percorso/2", 80)

			server.http_header_extra = {"Content-Type" => "text/xml"}
			@path = server.call("percorso.Cerca", @token,  from, to, {mezzo: 1, piedi: 0, bus:true, metro:false, ferro:false, carpooling:false, max_distanza_bici:0 },Time.now.strftime("%Y-%m-%d %H:%M:%S"), "IT")
			
			return @path 
		rescue XMLRPC::FaultException => e
		  puts "Error:"
		  puts e.faultCode
		  puts e.faultString
		end			
	end
	def get_stops(percorso, mezzo, data )
	  #https://bitbucket.org/agenziamobilita/muoversi-a-roma/wiki/percorso.Cerca
	  begin
			XMLRPC::Config.module_eval do
			    remove_const :ENABLE_NIL_PARSER
			    const_set :ENABLE_NIL_PARSER, true
			end
			server = XMLRPC::Client.new("muovi.roma.it", "/ws/xml/paline/7", 80)

			server.http_header_extra = {"Content-Type" => "text/xml"}
			@path = server.call("paline.Percorso", @token,  percorso, mezzo, data, "IT")
			
			return @path 
		rescue XMLRPC::FaultException => e
		  puts "Error:"
		  puts e.faultCode
		  puts e.faultString
		end			
	end
end

class BusStop
	BUS_STOPS={
		#route_id,service_id,trip_id,direction_id,shape_id
  		"913.1"=>[["4011354429","41.905318521064","12.4772504271675","1"],["4011354429","41.9053872565387","12.4772581569602","2"]],
  		"913.0"=>[["1278125004","41.9389642900362","12.4211157767467","1"],["1278125004","41.9390736627","12.4210148191618","2"]]
	}

end

get '/authenticate' do 
	@atac=AtacProxy.new(session[:token])
	session[:token]=@atac.token
	session[:token]
end

get '/trace_route' do
	@atac=AtacProxy.new(session[:token])
	bus_number=params[:bus_number] || "913"

	bus_stop_number=params[:bus_stop_number] || "fermata:70359"
	address_from=params[:address_from] || "Piazza Cavour"
	geo_from=params[:geo_from] 
	address_to=params[:address_to] || "Via Polibio"

	r1=@atac.search_path(address_from, address_to)

	tratto=r1["indicazioni"].map{|x| x["tratto"]}.compact.select{|x| x["id_linea"]==bus_number}.first
	percorso=tratto["id"].split("-").last

	r2=@atac.get_stops(percorso,"","")
	fermate=r2["risposta"]["fermate"]

	nodi=r1["indicazioni"].map{|x| x["nodo"] if x["nodo"] && x["nodo"]["tipo"]=="F"}.compact
	fermata_stop=fermate.select{|x| x["id_palina"]==nodi[1]["id"]}
	
	percorso ||= "55148"
	
	last_resp=fermate.map do |f|
	 f["start"]="1" if f["id_palina"]==nodi[0]["id"]
	 f["current"]="1" if f["id_palina"]==nodi[0]["id"]
	 f["last"]="1" if f["id_palina"]==nodi[1]["id"]
	 f
	end
	x={
		#tratto_1: tratto,
		#percorso: percorso,
		#nodo_start: nodi[0],
		#nodo_end: nodi[1],
		#fermata: fermata_stop,

		fermate: last_resp,


		#r1_indicazioni_count: r1["indicazioni"].size,
		#r1_indicazioni_nodi: r1["indicazioni"].map{|x| x["nodo"]}.compact,
		#r1_indicazioni_tratti: r1["indicazioni"].map{|x| x["tratto"]}.compact,
		#r1_stat: r1["stat"],
		#r2: r2,
	    #r2_fermate: r2["risposta"]["fermate"],
	    #r2_percorso: r2["risposta"]["percorso"],
	    #r2_percorsi: r2["risposta"]["percorsi"],
	    #r2_orari_partenza_vicini: r2["risposta"]["orari_partenza_vicini"],
	    #r2_orari_partenza: r2["risposta"]["orari_partenza"],
	    #r2_nessuna_partenza: r2["risposta"]["nessuna_partenza"]
	}
	
	
	
end


