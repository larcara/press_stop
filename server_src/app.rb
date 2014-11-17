require "sinatra"
require "sinatra/reloader" if development?
require "haml"
require "less"
require 'therubyracer'
require 'mongoid'
require 'json/ext' # required for .to_json
require 'csv'
require 'net/http'

require_relative "./lib/xmlrpc/client"
Mongoid.load!("./config/mongoid.yml")

#API_KEY="TTU8rKwDFEN4uL4iuyO9wlNDTJE78kXR"
API_KEY='bL5fwQZNDFdHkIR1hjxYCFIBrVRV78Hw'
set :port, 8080
set :bind, '0.0.0.0'
set :sessions, true



class TraceData
	include Mongoid::Document	
	field :session_id
	field :fermate, :type => Array
	field :num_fermate
end

class BusStop
  include Mongoid::Document
  field :stop_id
  field :stop_code
  field :stop_name
  field :stop_desc
  field :stop_url
  field :stop_order, type: Integer
  field :location, type: Hash  # [lng,lat]
  index({ location: "2d" })
  index({ stop_id: 1 }, { unique: true, name: "stop_id_index" })
  belongs_to :bus_line
end

class BusTrip
	include Mongoid::Document	
	field :trip_id
	
end
class BusLine
  include Mongoid::Document
  field :bus_number
  field :line_number
  field :direction
  field :description
  field :importata , type: Integer , default: 0
  has_many :bus_stops
  embeds_many :bus_trips
  index({ line_number: 1 }, { unique: true, name: "line_number_index" })
  #index({ "bus_stops.location" => "2d" })

  def to_label
  	"#{bus_number} #{direction}"
  end  
end

class AtacProxy
	attr_accessor :token, :service_paline , :service_percorso
	def initialize(_token)
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
	def get_stops(percorso, mezzo, data )
		#puts ["paline.Percorso", @token,  percorso, mezzo, data, "IT"]
		stops = @service_paline.call("paline.Percorso", @token,  percorso, mezzo, data, "IT")
	end
	def get_linee(palina)
		linee = @service_paline.call("paline.PalinaLinee", @token,  palina,  "IT")
	end
	def get_percorsi(linea)
		puts "get perscorsi per #{linea}"
		linee = @service_paline.call("paline.Percorsi", @token,  linea,  "IT")
	end

	def smart_search(query)
		result = @service_paline.call("paline.SmartSearch", @token, query)
	end
end




get "/" do
	haml :index
end

get '/authenticate' do 
	@atac= AtacProxy.new(session[:token])
	session[:token]=@atac.token

end

get '/application.css' do
  less :"less/app/app", :paths => ["views"]
end

get '/home' do 
  @lat=(params[:lat] || "41.9014").to_f
  @lng=(params[:lng] || "12.4801").to_f
  @atac= AtacProxy.new(session[:token])
  linee=BusStop.geo_near({lon:@lng,lat:@lat}).max_distance(0.005).map{ |x| [x.bus_line.line_number, "#{x.bus_line.to_label}"]}.uniq
  @linee=linee.sort
  haml :home
end

get '/trace' do
	line_number=session[:line_number]
	bl=BusLine.where(line_number: line_number).first

	current_position = [params[:lng].to_f,params[:lat].to_f]
	near_stop=bl.bus_stops.geo_near(current_position).first
	stops=bl.bus_stops

	fermate=[]
	final_id=1000
	stops.each_with_index do |stop, i|
		fermata={show: true, final: false, current: false, nome: stop.stop_name, lat: stop.location[1],  lng: stop.location[0] }
		fermata[:current]=true if stop.id==near_stop.id
		if stop.id == session[:bus_stop_to_id]
			fermata[:final]=true
			final_id = i
		end
		fermata[:show] = false if i > final_id.to_i
		fermate << fermata
	end
	@last_resp=fermate

	haml :trace
end

post '/start_trace' do
	#print params
	@atac=AtacProxy.new(session[:token])
	session[:line_number] = params[:bus_number]
	line_number=session[:line_number]
	# : params[:bus_number2].blank?
#	bus_stop_number=params[:bus_stop_number] || "fermata:70359"
	address_from="punto:(#{params[:address_from_geo]})" 
#	geo_from=params[:geo_from]
	address_to="punto:(#{params[:address_to_geo]})" 
	session[:address_from_geo] = [params[:lng].to_f,params[:lat].to_f]
	session[:address_to_geo] = params[:address_to_geo].split(",").map{|x| x.to_f}
	bl=BusLine.where(line_number: line_number).first
	stops=bl.bus_stops
	bus_stop_from=bl.bus_stops.geo_near(session[:address_from_geo]).first

	bus_stop_to=bl.bus_stops.geo_near(session[:address_to_geo]).first
	session[:bus_stop_to_id]=bus_stop_to.id
  
    print bus_stop_from.inspect
    print "\n"
    print bus_stop_to.inspect
    print "\n"
    
	
	#percorsi =  @atac.get_percorsi(bus_number)
	tratto=nil
	tratto_next=nil
	fermate=[]
	percorso=nil
	num_fermate=nil
    fermata_corrente=nil
	#paline_vicine= @atac.smart_search("punto:(#{params[:lat]},#{params[:lng]})")["risposta"]
  	#paline_vicine = paline_vicine["paline_extra"].map{|p| p["id_palina"]}

	#percorsi["risposta"]["percorsi"].each do |linea|
	#  tratto=nil
	#  tratto_next=nil
	#  fermate=nil
	#  percorso=nil
	#  fermate=@atac.get_stops(linea["id_percorso"], "", "")
	#  fermate=fermate["risposta"]["fermate"]

	  capolinea=bl.bus_stops[0] # fermate[0]["id_palina"]
	  #percorso=@atac.search_path("fermata:#{capolinea}", address_to)

	  # percorso["indicazioni"].each_with_index do |x,i|
	  # 	 if x["tratto"] && x["tratto"]["id_linea"]==bus_number.to_s
	  # 	 	tratto=percorso["indicazioni"][i]["tratto"]
	  # 	 	num_fermate=tratto["info_tratto"].scan(/Per (.*) fermate/i).flatten[0].to_i
	  # 	 	tratto_next=percorso["indicazioni"][i+1]["tratto"] if percorso["indicazioni"][i+1]
	  # 	 	fermata_stop=fermate[num_fermate]
	  # 	 	fermata_corrente=nil
	  # 	 	fermate.each_with_index do |f,i|
	  # 	 		f["show"]=true
	  # 	 		f["show"]=false if  fermata_corrente==nil
	  # 	 		f["show"]=false if  i > num_fermate
			# 	if paline_vicine.include? f["id_palina"]
			# 		fermata_corrente ||= i
			# 		f["current"]=true 
			# 		if i==( num_fermate-1)
			# 			haml :press_stop
			# 			return
			# 		end 
			# 	end	
	  # 	 	end
	  # 	 	break
	  # 	 end
	  # end
	  # break if tratto
	#end
    final_id=1000
	stops.each_with_index do |stop, i|
		fermata={show: true, final: false, current: false, nome: stop.stop_name, lat: stop.location[1],  lng: stop.location[0]}
		fermata[:current]=true if stop.id == bus_stop_from.id
		if stop.id == session[:bus_stop_to_id]
			fermata[:final]=true
			final_id = i
		end
		fermata[:show] = false if i > final_id.to_i

		fermate << fermata
	end

	#puts "tratto: #{tratto}"
	#puts "fermate: #{fermate}"
	#puts "paline vicine: #{paline_vicine}"

	#puts "num_fermata: #{num_fermate}"
	#puts "tratto_next: #{tratto_next}"

	if bus_stop_to.blank?
	  @last_resp=[]
	  @error="Non ci sono percorsi per arrivare a #{address_to} con la linea #{bus_number}"
	end

	
	@last_resp=fermate
	params[:session_id]=session[:session_id]
	TraceData.create(session_id: params[:session_id], num_fermate: num_fermate, fermate: fermate)
	
	#@last_resp=[@last_resp[fermata_corrente-1],@last_resp[fermata_corrente],@last_resp[fermata_corrente+1],@last_resp[-2],@last_resp[-1]]
	
	
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

get "/create_index" do
	BusStop.create_indexes()
	BusLine.create_indexes()
end

delete "/import_stops" do
	#BusLine.delete_all
	#BusStop.delete_all
	@atac= AtacProxy.new(session[:token])
	@stops=CSV.read("/root/stops.txt", :headers => :true, :header_converters => :symbol, :col_sep => ',')
	@stops=@stops.group_by{|x| x[0]}
	#stop=@stops["71619"][0]
	#print "\n"
	#print stop[:stop_lon]
	#print "\n"
	
	

	@lines=CSV.read("/root/routes.txt", :headers => :true, :header_converters => :symbol, :col_sep => ',')
	@lines.each do |line|
  		bl=BusLine.where(bus_number: line[0]).first
  		puts bl.inspect
		if (bl.blank? ||  bl.importata == 0) 
			percorsi=@atac.get_percorsi(line[0])	
			#percorsi: {"id_richiesta"=>"bfdebe230d67f812462e6ee3851ba019", 
			#		"risposta"=>{"monitorata"=>1, "id_news"=>-1, "abilitata"=>1, 
			#			"percorsi"=>[{"id_percorso"=>"50516", "descrizione"=>"Deviata Limitata Scolastica", "capolinea"=>"Marianne"},
			# 					  	 {"id_percorso"=>"50466", "descrizione"=>"", "capolinea"=>"P.le Stazione Del Lido (RL)"}]}}
			percorsi["risposta"]["percorsi"].each do |percorso|
				if bl
					bl.bus_stops.destroy
					bl.destroy
				end
				bl=BusLine.create(bus_number: line[0] , line_number: percorso["id_percorso"], description: percorso["descrizione"],
								 direction: percorso["capolinea"], importata: 0)

				fermate=@atac.get_stops(percorso["id_percorso"], "", "")["risposta"]["fermate"]
				#fermate=[]
								#risposta=> {
								#"percorso"=> ....
								#"no_orari"=>false, "orari_partenza_vicini"=>[], "abilitato"=>1, 
								#"percorsi"=>[ .... ]
								#"fermate"=>
								# 	[{"stato_traffico"=>0, "nome_ricapitalizzato"=>"Mombasiglio", "id_palina"=>"71619", "soppressa"=>false, "nome"=>"MOMBASIGLIO"},
								# 	 {"stato_traffico"=>-1, "nome_ricapitalizzato"=>"Trofarello", "id_palina"=>"71621", "soppressa"=>false, "nome"=>"TROFARELLO"},
								# 	 {"stato_traffico"=>-1, "nome_ricapitalizzato"=>"Casalotti/Ormea", "id_palina"=>"71623", "soppressa"=>false, "nome"=>"CASALOTTI/ORMEA"},
								# 	 {"stato_traffico"=>-1, "nome_ricapitalizzato"=>"Casalotti/Maretto", "id_palina"=>"71625", "soppressa"=>false, "nome"=>"CASALOTTI/MARETTO"},
				progressivo=0
				fermate.each do |fermata|

					if bl.bus_stops.where(stop_id: fermata["id_palina"]).count == 0

						stop=@stops[fermata["id_palina"]][0] if  @stops[fermata["id_palina"]]
						stop ||= {}
						#print "\n"
						#print stop
						#print "\n---------\n"
						progressivo+=1
						bl.bus_stops.create(stop_id: fermata["id_palina"] , stop_code: fermata["id_palina"],
										 stop_name: fermata["nome"], stop_desc: fermata["nome_ricapitalizzato"], stop_url: "",
										 location: {lon: stop[:stop_lon].to_f, lat: stop[:stop_lat].to_f	}, stop_order: progressivo)
					end 								
				end
				bl[:importata]=1
				bl.save
			end
		end
		#class BusStop stop_id: , stop_code:, stop_name: , stop_desc:, stop_url: location: [lng,lat]
		#class BusLine bus_number: , line_number: , direction:, bus_stops:	
	end

end
