require "sinatra"
require "sinatra/reloader" if development?
require "xmlrpc/client"

#API_KEY="TTU8rKwDFEN4uL4iuyO9wlNDTJE78kXR"
API_KEY='bL5fwQZNDFdHkIR1hjxYCFIBrVRV78Hw'
get '/authenticate' do 
	server = XMLRPC::Client.new_from_uri("http://muovi.roma.it/ws/xml/autenticazione/1")
	server.http_header_extra = { 'Content-Type' => 'text/xml' }
	server.http_header_extra = { 'Accept' => 'text/xml' }
	puts "#{server}"
	begin
	  param = server.call("autenticazione.Accedi", API_KEY, '')
	  puts "#{param}"
	rescue XMLRPC::FaultException => e
	  puts "Error:"
	  puts e.faultCode
	  puts e.faultString
	end	
end
