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
              "buttons": [
                buttons[0], buttons[1], buttons[2]
              ]
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
              "text": 'Let\'s help you spend that 💸 with ease'
            },
            "footer": {
              "text": 'Payments services available'
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
                      "description": 'Send money to another Wa-Pay wallet'
                    },
                    {
                      "id": 'wallet-to-mpesa',
                      "title": 'Wa-Pay to M-Pesa',
                      "description": 'Send money to an M-Pesa registered phone'
                    },
                    {
                      "id": 'wallet-to-bank',
                      "title": 'Wa-Pay to Bank',
                      "description": 'Send money to a bank account'
                    }
                  ]
                },
                {
                  "title": 'Shopping & Bills',
                  "rows": [
                    {
                      "id": 'wa-pay-business-account',
                      "title": 'Wa-Pay Bills',
                      "description": 'Send money from wallet to Wa-Pay business account'
                    }
                  ]
                },
                {
                  "title": 'Airtime and Data',
                  "rows": [
                    {
                      "id": 'buy-airtime',
                      "title": 'Buy Airtime',
                      "description": 'Buy airtime with Wa-Pay'
                    },
                    {
                      "id": 'buy-data-bundles',
                      "title": 'Buy Data Bundles',
                      "description": 'Buy data bundles with Wa-Pay'
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
                "formatted_name": 'Customer Relations, Wa-Pay',
                "first_name": 'Ochieng',
                "last_name": 'Otieno'
              },
              "org": {
                "company": 'Wa-Pay',
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
