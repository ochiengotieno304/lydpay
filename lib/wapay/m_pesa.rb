# frozen_string_literal: true

require 'faraday'
require 'ostruct'
require 'base64'

module Wapay
  class MPesa

    def self.authorization_token
      response = connection.get('/oauth/v1/generate?grant_type=client_credentials')
      response.body['access_token']
    end

    @timestamp = Time.now.strftime('%Y%m%d%H%M%S')

    def self.stk_push
      response = connection.post('/mpesa/stkpush/v1/processrequest') do |req|
        req.headers = { 'Authorization' => "Bearer #{authorization_token}" }
        req.body = {
          "BusinessShortCode": 174_379,
          "Password": Base64.strict_encode64("174379#{ENV['DARAJA_PASS_KEY']}#{@timestamp}"),
          "Timestamp": @timestamp,
          "TransactionType": 'CustomerPayBillOnline',
          "Amount": 1,
          "PartyA": 254_708_374_149,
          "PartyB": 174_379,
          "PhoneNumber": 254_743_287_562,
          "CallBackURL": 'https://3c5334842c52-15660798139000638402.ngrok-free.app/webhook/mpesa',
          "AccountReference": 'LydPay',
          "TransactionDesc": 'Payment of X'
        }
      end

      response.body
    end

    def self.init_connection
      @connection = Faraday.new('https://sandbox.safaricom.co.ke') do |f|
        f.request :json
        f.request :authorization, :basic, ENV['DARAJA_CONSUMER_KEY'], ENV['DARAJA_CONSUMER_SECRET']
        f.response :json
        f.response :logger, ::Logger.new($stdout), bodies: true
        f.adapter Faraday.default_adapter
      end
    end

    private_class_method def self.connection
      @connection ||= init_connection
    end

  end
end
