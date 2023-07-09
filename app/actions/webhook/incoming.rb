# frozen_string_literal: true

require 'faraday'

module Wapay
  module Actions
    module Webhook
      class Incoming < Wapay::Action
        def handle(request, response)
          request_body = request.body.read

          body = JSON.parse(request_body, object_class: OpenStruct)

          if body.object
            if body.entry &&
               body.entry[0].changes &&
               body.entry[0].changes[0] &&
               body.entry[0].changes[0].value.messages &&
               body.entry[0].changes[0].value.messages[0]

              # phone_number_id = body.entry[0].changes[0].value.metadata.phone_number_id
              from = body.entry[0].changes[0].value.messages[0].from
              from_name = body.entry[0].changes[0].value.contacts[0].profile.name
              # # message = body.entry[0].changes[0].value.messages[0].text.body
              message_type = body.entry[0].changes[0].value.messages[0].type

              Faraday.new('https://graph.facebook.com/v12.0') do |f|
                f.request :json
                f.response :json
                f.adapter Faraday.default_adapter
              end

              Requests.send_button_message(from, from_name) if message_type == 'text'

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
                  Requests.send_text_message(from, from_name, 'your Wa-Pay account registration was successful')
                  Requests.send_list_message(from, from_name)
                  # Cancel Registration
                elsif button_id == 'cancel-registration'
                  Requests.send_text_message(from, from_name,
                                             'thank you for checking out Wa-Pay, you can contact us for more info')
                  Requests.send_contact_message(from)
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
