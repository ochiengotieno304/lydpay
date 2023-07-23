# frozen_string_literal: true

require 'faraday'

module Wapay
  class AirtimeAndData
    @username = ENV['AT_USERNAME']
    @api_key = ENV['AT_API_KEY']
    @endpoint = ENV['AT_ENDPOINT']

    def self.send_airtime(recipient, amount)
      data = { 'username' => 'sandbox',
               'recipients' => "[{\"phoneNumber\": \"#{recipient}\",\"amount\": \"KES #{amount}\" }]" }
      connection.post('/version1/airtime/send') do |req|
        req.headers['apiKey'] = @api_key
        req.body = data
      end
    end

    def self.send_data_bundles(recipient, amount)
      data = {
        username: @username,
        recipients: [
          { phoneNumber: recipient, amount: "KES #{amount}" }
        ]
      }
      connection.post('/mobile/data/request') do |req|
        req.headers['apiKey'] = @api_key
        req.body = data
      end
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
