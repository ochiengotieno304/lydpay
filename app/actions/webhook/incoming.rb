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
                button_id = body.entry[0].changes[0].value.messages[0].interactive.button_reply.id

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
                          "text": 'Choose Payment Option'
                        },
                        "body": {
                          "text": 'BODY_TEXT'
                        },
                        "footer": {
                          "text": 'FOOTER_TEXT'
                        },
                        "action": {
                          "button": 'BUTTON_TEXT',
                          "sections": [
                            {
                              "title": 'SECTION_1_TITLE',
                              "rows": [
                                {
                                  "id": 'SECTION_1_ROW_1_ID',
                                  "title": 'SECTION_1_ROW_1_TITLE',
                                  "description": 'SECTION_1_ROW_1_DESCRIPTION'
                                },
                                {
                                  "id": 'SECTION_1_ROW_2_ID',
                                  "title": 'SECTION_1_ROW_2_TITLE',
                                  "description": 'SECTION_1_ROW_2_DESCRIPTION'
                                }
                              ]
                            },
                            {
                              "title": 'SECTION_2_TITLE',
                              "rows": [
                                {
                                  "id": 'SECTION_2_ROW_1_ID',
                                  "title": 'SECTION_2_ROW_1_TITLE',
                                  "description": 'SECTION_2_ROW_1_DESCRIPTION'
                                },
                                {
                                  "id": 'SECTION_2_ROW_2_ID',
                                  "title": 'SECTION_2_ROW_2_TITLE',
                                  "description": 'SECTION_2_ROW_2_DESCRIPTION'
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
                        "body": 'Thank you for checking out our product, contact us for more info'
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
