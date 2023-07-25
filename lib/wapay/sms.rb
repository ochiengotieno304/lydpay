# frozen_string_literal: true

module Wapay
  class Sms
    @username = ENV['AT_USERNAME']
    @api_key = ENV['AT_API_KEY']
    @endpoint = ENV['AT_ENDPOINT']

    def self.send_sms(recipient, message)
      recipient = recipient[1..].rjust(13, '+254')
      data = {
        'username' => 'sandbox',
        'to' => recipient,
        'from' => '7633',
        'message' => message
      }

      connection.post('/version1/messaging') do |req|
        req.headers['apiKey'] = @api_key
        req.body = data
      end
    end

    def self.inti_connection
      @connection = Faraday.new(@endpoint) do |f|
        f.headers['Accept'] = 'application/json'
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
