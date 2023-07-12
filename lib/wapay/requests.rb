# frozen_string_literal: true

require 'faraday'
module Wapay
  class Requests
    attr_reader :access_token, :phone_number_id, :conn

    @access_token = ENV['ACCESS_TOKEN']
    @phone_number_id = ENV['PHONE_NUMBER_ID']
    @mobile = ENV['MOBILE']
    @email = ENV['EMAIL']

    @conn = Faraday.new("https://graph.facebook.com/v17.0/#{@phone_number_id}/messages?access_token=#{@access_token}") do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end

    def self.send_text_message(to_phone, message)
      @conn.post(nil) do |req|
        req.body = {
          "messaging_product": 'whatsapp',
          "recipient_type": 'individual',
          "to": to_phone,
          "type": 'text',
          "text": {
            "preview_url": false,
            "body": message
          }
        }
      end
    end

    def self.send_button_message(to_phone, message, buttons)
      button_actions = buttons.to_json
      @conn.post(nil) do |req|
        req.body = {
          "messaging_product": 'whatsapp',
          "recipient_type": 'individual',
          "to": to_phone,
          "type": 'interactive',
          "interactive": {
            "type": 'button',
            "body": {
              "text": message
            },
            "action": {
              "buttons": button_actions
            }
          }
        }
      end
    end

    def self.send_list_message(to_phone, message)
      @conn.post(nil) do |req|
        req.body = {
          "messaging_product": 'whatsapp',
          "recipient_type": 'individual',
          "to": to_phone,
          "type": 'interactive',
          "interactive": {
            "type": 'list',
            "header": {
              "type": 'text',
              "text": message
            },
            "body": {
              "text": 'Send money, shop & pay bills with ease'
            },
            "footer": {
              "text": 'Payment services available'
            },
            "action": {
              "button": 'Make Payments',
              "sections": [
                {
                  "title": 'Send Money',
                  "rows": [
                    {
                      "id": 'wallet-to-wallet',
                      "title": 'Wallet to Wallet',
                      "description": 'Send money to another PayChat wallet'
                    },
                    {
                      "id": 'wallet-to-mpesa',
                      "title": 'PayChat to M-Pesa',
                      "description": 'Send money to an M-Pesa registered phone'
                    },
                    {
                      "id": 'wallet-to-bank',
                      "title": 'PayChat to Bank',
                      "description": 'Send money to a bank account'
                    }
                  ]
                },
                {
                  "title": 'Shopping & Bills',
                  "rows": [
                    {
                      "id": 'wa-pay-business-account',
                      "title": 'PayChat Tills',
                      "description": 'Send money from wallet to PayChat business account'
                    }
                  ]
                },
                {
                  "title": 'Airtime and Data',
                  "rows": [
                    {
                      "id": 'buy-airtime',
                      "title": 'Buy Airtime',
                      "description": 'Buy airtime with PayChat'
                    },
                    {
                      "id": 'buy-data-bundles',
                      "title": 'Buy Data Bundles',
                      "description": 'Buy data bundles with PayChat'
                    }
                  ]
                },
                {
                  "title": 'PayChat Account',
                  "rows": [
                    {
                      "id": 'top-up-wallet',
                      "title": 'Top up wallet',
                      "description": 'Top up your PayChat wallet'
                    },
                    {
                      "id": 'account-balance',
                      "title": 'Wallet balance',
                      "description": 'Check wallet balance'
                    }
                  ]
                }
              ]
            }
          }
        }
      end
    end

    def self.send_contact_message(to_phone)
      @conn.post(nil) do |req|
        req.body = {
          "messaging_product": 'whatsapp',
          "recipient_type": 'individual',
          "to": to_phone,
          "type": 'contacts',
          "contacts": [
            {
              "addresses": [
                {
                  "city": 'Nairobi',
                  "country": 'Kenya'
                }
              ],
              "emails": [
                {
                  "email": @email,
                  "type": 'WORK'
                }
              ],
              "name": {
                "formatted_name": 'Customer Relations, PayChat',
                "first_name": 'Ochieng',
                "last_name": 'Otieno'
              },
              "org": {
                "company": 'PayChat',
                "department": 'Customer Relations'
              },
              "phones": [
                {
                  "phone": @mobile,
                  "type": 'WORK',
                  "wa_id": '254743287562'
                }
              ]
            }
          ]
        }
      end
    end
  end
end
