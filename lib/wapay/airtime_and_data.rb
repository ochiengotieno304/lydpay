# frozen_string_literal: true

require 'faraday'
require 'ostruct'

module Wapay
  class AirtimeAndData
    @username = ENV['AT_USERNAME']
    @api_key = ENV['AT_API_KEY_LIVE']
    @endpoint = ENV['AT_ENDPOINT_LIVE']

    def self.send_airtime(recipient, amount)
      from_account_balance = User.user_data(recipient).balance.to_i

      if from_account_balance > amount.to_i
        int_recipient = recipient[1..].rjust(13, '+254')
        data = { 'username' => @username,
                 'recipients' => "[{\"phoneNumber\": \"#{int_recipient}\",\"amount\": \"KES #{amount}\" }]" }
        response = connection.post('/version1/airtime/send') do |req|
          req.headers['apiKey'] = @api_key
          req.body = data
        end

        res = JSON.parse(response.body.to_json, object_class: OpenStruct)
        if res.errorMessage == 'None'
          if res.responses[0].status == 'Sent'
            User.update_user(recipient, { 'balance' => from_account_balance - amount.to_i })
            'ACC01'
          end
        else
          'ERR03' # request not complete
        end
      else
        'ERR01' # insufficient funds
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
