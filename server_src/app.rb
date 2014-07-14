require "sinatra"
require "xmlrpc/client"

#API_KEY="TTU8rKwDFEN4uL4iuyO9wlNDTJE78kXR"
API_KEY='bL5fwQZNDFdHkIR1hjxYCFIBrVRV78Hw'
get '/authenticate' do |variable|
	server = XMLRPC::Client.new("'http://muovi.roma.it/", "/ws/xml/", 80)
	begin
	  param = server.call("autenticazione.Accedi", API_KEY)
	  puts "#{param}"
	rescue XMLRPC::FaultException => e
	  puts "Error:"
	  puts e.faultCode
	  puts e.faultString
	end	
end
