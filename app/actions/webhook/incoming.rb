# frozen_string_literal: true

require 'faraday'

module Wapay
  module Actions
    module Webhook
      class Incoming < Wapay::Action
        def handle(request, response)
          access_token = ENV['ACCESS_TOKEN']

          request_body = request.body.read

          body = JSON.parse(request_body, object_class: OpenStruct)

          if body.object
            if body.entry and
               body.entry[0].changes and
               body.entry[0].changes[0] and
               body.entry[0].changes[0].value.messages and
               body.entry[0].changes[0].value.messages[0]

              phone_number_id = body.entry[0].changes[0].value.metadata.phone_number_id
              from = body.entry[0].changes[0].value.messages[0].from
              body.entry[0].changes[0].value.messages[0].text.body

              conn = Faraday.new(
                url: 'https://graph.facebook.com/v17.0',
                headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{access_token}" }
              )

              response.body = conn.post("/#{phone_number_id}/messages") do |req|
                req.body = {
                  "messaging_product": 'whatsapp',
                  "recipient_type": 'individual',
                  "to": from,
                  "type": 'interactive',
                  "interactive": {
                    "type": 'button',
                    "body": {
                      "text": 'BUTTON_TEXT'
                    },
                    "action": {
                      "buttons": [
                        {
                          "type": 'reply',
                          "reply": {
                            "id": 'UNIQUE_BUTTON_ID_1',
                            "title": 'BUTTON_TITLE_1'
                          }
                        },
                        {
                          "type": 'reply',
                          "reply": {
                            "id": 'UNIQUE_BUTTON_ID_2',
                            "title": 'BUTTON_TITLE_2'
                          }
                        }
                      ]
                    }
                  }
                }
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
