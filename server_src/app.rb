require "sinatra"
require "sinatra/reloader" if development?
require "xmlrpc/client"
require_relative "./lib/xmlrpc/client"

#API_KEY="TTU8rKwDFEN4uL4iuyO9wlNDTJE78kXR"
API_KEY='bL5fwQZNDFdHkIR1hjxYCFIBrVRV78Hw'
get '/authenticate' do 
	server = XMLRPC::Client.new("muovi.roma.it", "/ws/xml/autenticazione/1", 80)
	puts "#{token}"
	rescue XMLRPC::FaultException => e
	  puts "Error:"
	  puts e.faultCode
	  puts e.faultString
	end	
end
