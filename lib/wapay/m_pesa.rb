# frozen_string_literal: true

require 'faraday'
require 'ostruct'
require 'base64'

module Wapay
  class MPesa
    @daraja_auth_key = ENV['DARAJA_AUTH_KEY']
    @daraja_pass_key = ENV['DARAJA_PASS_KEY']
    @timestamp = Time.now.strftime('%Y%m%d%H%M%S')

    def self.authorization_token
      response = connection.get('/oauth/v1/generate?grant_type=client_credentials') do |req|
        req.headers = { 'Authorization' => "Basic #{@daraja_auth_key}" }
      end

      response.body['access_token']
    end

    def self.stk_push
      response = connection.post('/mpesa/stkpush/v1/processrequest') do |req|
        req.headers = { 'Authorization' => "Bearer #{authorization_token}" }
        req.body = {
          "BusinessShortCode": 174_379,
          "Password": Base64.encode64("174379#{@daraja_pass_key}#{@timestamp}"),
          "Timestamp": @timestamp,
          "TransactionType": 'CustomerPayBillOnline',
          "Amount": 1,
          "PartyA": 254_708_374_149,
          "PartyB": 174_379,
          "PhoneNumber": 254_743_287_562,
          "CallBackURL": 'https://mydomain.com/path',
          "AccountReference": 'LydPay',
          "TransactionDesc": 'Payment of X'
        }
      end

      response.body
    end

    def self.init_connection
      @connection = Faraday.new('https://sandbox.safaricom.co.ke') do |f|
        f.request :json
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
