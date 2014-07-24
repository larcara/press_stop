require "sinatra"
require "sinatra/reloader" if development?
require "haml"
require "less"
require 'therubyracer'
require 'mongoid'
require 'json/ext' # required for .to_json
require 'csv'

require_relative "./lib/xmlrpc/client"
Mongoid.load!("./config/mongoid.yml")

#API_KEY="TTU8rKwDFEN4uL4iuyO9wlNDTJE78kXR"
API_KEY='bL5fwQZNDFdHkIR1hjxYCFIBrVRV78Hw'
set :port, 8080
set :bind, '0.0.0.0'
set :session, true




# before do
#    content_type :json    
#    headers 'Access-Control-Allow-Origin' => '*', 
#             'Access-Control-Allow-Methods' => ['OPTIONS', 'GET', 'POST']  
# end

# set :protection, false

class AtacProxy
	attr_accessor :token, :service_paline
	def initialize(_token)
		unless _token.blank?
			@token=_token
			@service_paline=  XMLRPC::Client.new("muovi.roma.it", "/ws/xml/paline/7", 80)	
		end
		begin
			puts "Creating new client"
			server = XMLRPC::Client.new("muovi.roma.it", "/ws/xml/autenticazione/1", 80)
			server.http_header_extra = {"Content-Type" => "text/xml"}
			@token = server.call("autenticazione.Accedi", API_KEY, '')
			puts "Created token #{@token}"
			@service_paline=  XMLRPC::Client.new("muovi.roma.it", "/ws/xml/paline/7", 80)
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
	def get_linee(palina)
		 begin
			XMLRPC::Config.module_eval do
			    remove_const :ENABLE_NIL_PARSER
			    const_set :ENABLE_NIL_PARSER, true
			end
			server = XMLRPC::Client.new("muovi.roma.it", "/ws/xml/paline/7", 80)

			server.http_header_extra = {"Content-Type" => "text/xml"}
			linee = server.call("paline.PalinaLinee", @token,  palina,  "IT")
			
			return linee
		rescue XMLRPC::FaultException => e
		  puts "Error:"
		  puts e.faultCode
		  puts e.faultString
		end		
	end

	def smart_search(query)
		result = service_paline.call("paline.SmartSearch", @token, query)
		return result
	end
end

class BusStop
  include Mongoid::Document
  field :stop_id
  field :stop_name
  field :location_type
  field :parent_station
  field :location, :type => Array  # [lat,lng]
  field :bus_number, :type => Array  
  index({ location: "2d" }, { min: -200, max: 200 })
  
end

get "/" do
	haml :index
end

get '/authenticate' do 
	session[:atac] ||= AtacProxy.new(session[:token])
	session[:token]=session[:atac].token

end

get '/application.css' do
  less :"less/app/app", :paths => ["views"]
end

get '/home' do 
  @lat=(params[:lat] || "41.9014").to_f
  @lng=(params[:lng] || "12.4801").to_f
  @atac= AtacProxy.new(session[:token])
  risposta= @atac.smart_search("punto:(#{params[:lat]},#{params[:lng]})")["risposta"]
  
  @bus_stops=risposta["paline_extra"].map{|x| x["id_palina"]}.uniq
  linee=[]
  begin
  	risposta["paline_extra"].each do |p|
  		tmp_linee=p["linee_info"].map{|x| x["id_linea"] }
  		BusStop.where(stop_id: p["id_palina"]).push(:bus_number, tmp_linee)
  		linee += tmp_linee
  	end
  rescue
  end
  @linee=linee.uniq
  #@bus_stops=BusStop.geo_near([  ,  ]).max_distance(0.002).map{|x| puts x.geo_near_distance; x.stop_id	}
  haml :home
end

post '/trace' do
	print params
	@atac=session[:atac] || AtacProxy.new(session[:token])
	bus_number=params[:bus_number2] || params[:bus_number] || "913F"
	

	bus_stop_number=params[:bus_stop_number] || "fermata:70359"
	address_from=params[:address_from] || "Piazza Cavour"
	geo_from=params[:geo_from]
	address_to=params[:address_to] || "Via Polibio"

	r1=@atac.search_path(address_from, address_to)

	#puts  r1 
	tratto=r1["indicazioni"].map{|x| x["tratto"]}.compact.select{|x| x["id_linea"]==bus_number}.first
	if tratto.blank?
	  @last_resp=[]
	  @error="Non ci sono percorsi per arrivare a #{address_to} con la linea #{bus_number}"
	else	  
	
	percorso=tratto["id"].split("-").last

	r2=@atac.get_stops(percorso,"","")
	fermate=r2["risposta"]["fermate"]

	nodi=r1["indicazioni"].map{|x| x["nodo"] if x["nodo"] && x["nodo"]["tipo"]=="F"}.compact
	puts  nodi.inspect
	puts  fermate.inspect

	fermata_stop=fermate.select{|x| x["id_palina"]==nodi[1]["id"]}

	percorso ||= "55148"
	
	@last_resp=fermate.map do |f|
	 f["start"]="1" if f["id_palina"]==nodi[0]["id"]
	 f["current"]="1" if f["id_palina"]==nodi[0]["id"]
	 f["last"]="1" if f["id_palina"]==nodi[1]["id"]
	 f
	end
	end
	
	x={
		#tratto_1: tratto,
		#percorso: percorso,
		#nodo_start: nodi[0],
		#nodo_end: nodi[1],
		#fermata: fermata_stop,

		fermate: @last_resp


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
	haml :trace
	

end


post "/import_stops" do
	text=params['file'][:tempfile].read
	text.gsub!(/\r\n?/, "\n")
	data=CSV.parse(text)
	data.shift #prima linea
	BusStop.delete_all
	data.each  do |x|
		#stop_id,stop_name,stop_lat,stop_lon,location_type,parent_station
		BusStop.create(stop_id: x[0], stop_name:x[1], location: [x[2].to_f,x[3].to_f], location_type: x[4], parent_station:x[5])
  		
	end

end