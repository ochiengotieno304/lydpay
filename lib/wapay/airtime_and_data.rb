# frozen_string_literal: true

require 'faraday'

module Wapay
  class AirtimeAndData
    @username = ENV['AT_USERNAME']
    @api_key = ENV['AT_API_KEY']
    @endpoint = ENV['AT_ENDPOINT']

    def self.send_airtime(recipient, amount)
      response = connection.post('/version1/airtime/send') do |req|
        req.headers['apiKey'] = @api_key
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = {
          username: @username,
          recipients: [{phoneNumber: recipient, amount: "KES #{amount}"}]
        }.to_json.to_s
      end

      puts response.body
    end

    def self.inti_connection
      @connection = Faraday.new(@endpoint) do |f|
        f.request :url_encoded
        f.response :json
        f.response :logger, ::Logger.new($stdout), bodies: true
        f.adapter Faraday.default_adapter
      end
    end

    private_class_method def self.connection
      @connection ||= inti_connection
    end
  end
end
