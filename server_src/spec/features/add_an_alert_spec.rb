require "spec_helper"

RSpec.describe "setup an alert", feature: true do
  before  { omniauth_hash = { 'provider' => 'twitter',
                  'uid' => '12345',
                  'info' => {
                      'name' => 'test',
                      'email' => 'test@nomail.test'
                  }
              }
              OmniAuth.config.add_mock(:twitter, omniauth_hash)
            }
  describe "#login" do
    subject { user }

    it "should redirect to twitter" do # the first test
      get '/alerts' # you are visiting the home page
      expect(last_response.status).to eq(302) # it will true if the home page load successfully
    end
    it "should load the home page" do # the first test
      get '/auth/twitter/callback' , nil , {"omniauth.auth" => OmniAuth.config.mock_auth[:twitter]}# you are visiting the home page
      follow_redirect!

      expect(last_response.status).to eq(200) # it will true if the home page load successfully
    end
  end
  describe "#add alert" do
    subject { user }
    
    it "should add an alert" do # the first test
      get '/auth/twitter/callback' , nil , {"omniauth.auth" => OmniAuth.config.mock_auth[:twitter]}# you are visiting the home pageomniauth_hash = { 'provider' => 'twitter',
      follow_redirect!
      post '/add_alert', {bus_stop: 70092, bus_line: 913}
      
      puts last_response.body
      expect(last_response.status).to eq(200) # it will true if the home page load successfully
    end
  end
end