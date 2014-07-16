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
	def get_path(from, to )
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
	bus_stop_number=params[:bus_stop_number] || "fermata:70359"
	address_from=params[:address_from] || "Largo Chigi, Roma"
	geo_from=params[:geo_from] 
	address_to=params[:address_to] || "Via Polibio"

	@atac.search_path(bus_stop_number, address_to)
	
end


