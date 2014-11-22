# This class is the core  *Alert* object
# An Alert is based on a bus_line (aka -percorso-) and store 
# info about line stops, line number and user asking for alert

# Author::    Luca Arcara  (mailto:larcara@gmail.com)
# Copyright:: Copyright (c) 2014 Luca Arcara
# License::   Distributes under the same terms as Ruby

#
# Usage:
#  you can  add an alert by call Alert.add_alert(bus_line: 913, bus_stop: 75779, user: "@lucaa76")
#

require 'mongoid'
require_relative "./atac_proxy.rb"
require 'twitter'
Mongoid.load!("./config/mongoid.yml", "development")



class Alert
	# This class holds the letters in the original
	# word or phrase. The is_anagram? method allows us
	# to test if subsequent words or phrases are
	# anagrams of the original.
	# * *Args*    :
  #   - +_track_number+ -> the track number that identify the line
  # * *Returns* :
  #   - a new alert object. Initialize the staging and refresh the data
  # * *Raises* :
  #   - +ArgumentError+ -> if no argument
  #
	def initialize(_track_number=nil, _bus_line=nil, _stop_number=nil)
    raise ArgumentError, "_track_number must be specified" if [_track_number, _bus_line, _stop_number] == [nil,nil,nil]
    @alert=BusAlert.where(percorso: _track_number).first
    @alert||=BusAlert.where(bus_line: _bus_line).in(stops: _stop_number).first

    if @alert.nil?  # a new track ... initialize from Atac
      atac_proxy=AtacProxy.new()
      response=atac_proxy.get_stops(_track_number)
      raise ArgumentError, "_track_number isn't valid" if response.nil?
      _bus_line=response["percorso"]["id_linea"]
      stops=response["fermate"]

      raise ArgumentError, "_track_number isn't valid" if (stops.nil? || stops.size==0)

      @alert=BusAlert.create(bus_line: _bus_line, percorso: _track_number, stops: stops.map{|x| x["id_palina"].to_i}, stops_data: stops.map{|x| x.delete("veicolo"); x.delete("stato_traffico"); x})
    end

  end
  def stops
   @alert.stops
  end
  def alert_data
   @alert.alert_data
  end

  def destroy
    @alert.delete
  end
  # Add am user alert to monitor 3 stops
  # given an *Alert* -stops- save stops numbers: [7008, 7009, 7040, 7890, 7440]
  #
  # if you ask to monitor stop number 7890  it return ["@user", [7009, 7040, 7890] ]
  #
  # * *Args*    :
  #   - +stop_number+ -> the track number that identify the line
  #   - +user+ -> the twitter user name
  # * *Returns* :
  #   - a new alert object. Initialize the staging and refresh the data
  # * *Raises* :
  #   - +ArgumentError+ -> if no argument
  #
  def add_alert_data!(user, stops )
    @alert.add_alert_data(user, stops)
  end

  class BusAlert
    include Mongoid::Document
    #field :stop_number
    #field :line
    field :percorso
    field :stops, type: Array #{"nome_ricapitalizzato"=>"Augusto Imperatore", "nome"=>"AUGUSTO IMPERATORE", "stato_traffico"=>0, "id_palina"=>"70359", "soppressa"=>false}
    field :last_update, type: Date, default: Proc.new{Date.today}
    field :alert_data, type: Array, default: []

    def add_alert_data(user, stops)
      current_user_alert = [user, []]
      puts "current_user_alert : #{current_user_alert.inspect}"
      current_user_alert[1] +=  stops
      puts "new current_user_alert : #{current_user_alert.inspect}"
      self.add_to_set(:alert_data, [current_user_alert])
      current_user_alert
    end
  end

  def self.add_alert(options={}) #line: params[:bus_line], stop: params[:bus_stop], user: @current_user
   alert=Alert.get_alert(options)
   index= alert.stops.index(options[:bus_stop])
   raise ArgumentError, "invalid _stop number " if index.nil?
   # x= [ ["primo", 1, 2,3] , ["secondo", 5,6,7] ] -> x.asssoc("primo") => ["primo", 1, 2,3]
   user_data = []
   user_data << alert.stops[index]
   user_data << alert.stops[index-1] if index > 1
   user_data << alert.stops[index-1] if index > 2
   return  alert.add_alert_data!(options[:user], user_data)


  end

  def self.check_alert(cicle_count, &block)
  	atac=AtacProxy.new()
    response=[]
    cicle_count.times do |i|
      puts "..#{i}.."
      BusAlert.exists(alert_data: 1).each do |percorso|
        #puts "percoros #{percorso}"
        response=atac.get_stops(percorso["percorso"].to_i)
        next_bus=response["orari_partenza_vicini"]
        busses=[]
        response["fermate"].each {|x| busses << x["id_palina"].to_i if x["veicolo"] }
        #puts busses.inspect

        percorso.alert_data.each do |user|
          #puts user.inspect
          #puts busses.inspect
          coming_bus=(user[1].flatten & busses)
          yield( user[0], "bus #{coming_bus} coming at #{user[1].last}!!!" ) unless coming_bus.empty?

        end

        #Luca    -> [1,1,1,nil,nil,nil,nil,1,1,1]
        #Giuseppe-> [nil,nil,1,1,1,nil,1,1,1,nil]
        #ATAC    -> [1: {}, 2:{V}, 3:{}, 4:{}, 5:{v}, 6:{}, 7:{}, 8::{}]
        #ATAC2    ->[1: nil, 2:{V}, 3:nil, 4:nil, 5:{v}, 6:nil, 7:nil, 8:nil]

        #ATAC & LUCA -> [nil,nil,2{V}, nil]

        sleep 1
      end
    end
    return true
  end
  def self.tweet_bus
    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV["CONSUMER_KEY"]
      config.consumer_secret     = ENV["CONSUMER_SECRET"]
      config.access_token        = ENV["YOUR_ACCESS_TOKEN"]
      config.access_token_secret = ENV["YOUR_ACCESS_SECRET"]
    end
    check_alert(100) {|user, message| client.update("#{user} #{message}")}
  end
  private
  # This method search for an alert based on track_number or [bus_line, bus_stop]
  # anagrams of the original.
  # * *Args*    :
  #   - +{bus_line, bus_stop, track_number}
  # * *Returns* :
  #   - an alert object.
  # * *Raises* :
  #   - +ArgumentError+ -> if no argument
  #
  def self.get_alert(options={})
    return Alert.new(options[:percorso]) unless options[:percorso].nil?


    a=AtacProxy.new()
    percorsi=a.get_percorsi(options[:bus_line])
    percorsi.each do |percorso|
      fermate=a.get_stops(percorso[0])
      fermate=fermate["fermate"].map{|x| x["id_palina"]}
      return Alert.new(percorso[0]) if fermate.include?(options[:bus_stop].to_s)
    end
    return nil
  end
end
