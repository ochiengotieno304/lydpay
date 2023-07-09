# frozen_string_literal: true

require 'faraday'

module Wapay
  module Actions
    module Webhook
      class Incoming < Wapay::Action
        def handle(request, response)
          access_token = ENV['ACCESS_TOKEN']
          mobile = ENV['MOBILE']
          email = ENV['EMAIL']

          request_body = request.body.read

          body = JSON.parse(request_body, object_class: OpenStruct)

          if body.object
            if body.entry &&
               body.entry[0].changes &&
               body.entry[0].changes[0] &&
               body.entry[0].changes[0].value.messages &&
               body.entry[0].changes[0].value.messages[0]

              phone_number_id = body.entry[0].changes[0].value.metadata.phone_number_id
              from = body.entry[0].changes[0].value.messages[0].from
              from_name = body.entry[0].changes[0].value.contacts[0].profile.name
              # # message = body.entry[0].changes[0].value.messages[0].text.body
              message_type = body.entry[0].changes[0].value.messages[0].type

              conn = Faraday.new('https://graph.facebook.com/v12.0') do |f|
                f.request :json
                f.response :json
                f.adapter Faraday.default_adapter
              end

              if message_type == 'text'
                # Registration Prompt
                conn.post("/#{phone_number_id}/messages?access_token=#{access_token}") do |req|
                  req.body = {
                    "messaging_product": 'whatsapp',
                    "recipient_type": 'individual',
                    "to": from,
                    "type": 'interactive',
                    "interactive": {
                      "type": 'button',
                      "body": {
                        "text": "Hello #{from_name}, Do you wish to register a new WA-Pay account"
                      },
                      "action": {
                        "buttons": [
                          {
                            "type": 'reply',
                            "reply": {
                              "id": 'confirm-registration',
                              "title": 'Yes'
                            }
                          },
                          {
                            "type": 'reply',
                            "reply": {
                              "id": 'cancel-registration',
                              "title": 'No'
                            }
                          }
                        ]
                      }
                    }
                  }
                end
              end

              if message_type == 'interactive'

                # Assuming `body` is the input data structure
                button_id = ''

                if body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.button_reply&.id
                  button_id = body.entry[0].changes[0].value.messages[0].interactive.button_reply.id
                elsif body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.list_reply&.id
                  button_id = body.entry[0].changes[0].value.messages[0].interactive.list_reply.id
                end

                # Registration confirmation
                if button_id == 'confirm-registration'
                  conn.post("/#{phone_number_id}/messages?access_token=#{access_token}") do |req|
                    req.body = {
                      "messaging_product": 'whatsapp',
                      "recipient_type": 'individual',
                      "to": from,
                      "type": 'text',
                      "text": {
                        "preview_url": false,
                        "body": 'Registration successful'
                      }
                    }
                  end
                  conn.post("/#{phone_number_id}/messages?access_token=#{access_token}") do |req|
                    req.body = {
                      "messaging_product": 'whatsapp',
                      "recipient_type": 'individual',
                      "to": from,
                      "type": 'interactive',
                      "interactive": {
                        "type": 'list',
                        "header": {
                          "type": 'text',
                          "text": "Hello, here's what you can do with Wa-Pay"
                        },
                        "body": {
                          "text": 'How would you like to spend today'
                        },
                        "footer": {
                          "text": 'Available payments options'
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

                  # Cancel Registration
                elsif button_id == 'cancel-registration'
                  conn.post("/#{phone_number_id}/messages?access_token=#{access_token}") do |req|
                    req.body = {
                      "messaging_product": 'whatsapp',
                      "recipient_type": 'individual',
                      "to": from,
                      "type": 'text',
                      "text": {
                        "preview_url": false,
                        "body": 'Thank you for checking out our product, for more info feel free to contact us'
                      }
                    }
                  end
                  conn.post("/#{phone_number_id}/messages?access_token=#{access_token}") do |req|
                    req.body = {
                      "messaging_product": 'whatsapp',
                      "recipient_type": 'individual',
                      "to": from,
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
                              "email": email,
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
                              "phone": mobile,
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
              response.status = 200
            end
          else
            response.status = 404
          end
        end
      end
    end
  end
end
