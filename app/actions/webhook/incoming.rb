# frozen_string_literal: true

require 'faraday'
require 'ostruct'

module Wapay
  module Actions
    module Webhook
      class Incoming < Wapay::Action
        def handle(request, response)
          session = OpenStruct.new(session_id: 'xyz', user: '254743287562', type: 'user-sign-up', step: 1)
          user_registered = false
          request_body = request.body.read

          body = JSON.parse(request_body, object_class: OpenStruct)

          if body.object
            if body.entry &&
               body.entry[0].changes &&
               body.entry[0].changes[0] &&
               body.entry[0].changes[0].value.messages &&
               body.entry[0].changes[0].value.messages[0]

              from = body.entry[0].changes[0].value.messages[0].from
              from_name = body.entry[0].changes[0].value.contacts[0].profile.name
              # message = body.entry[0].changes[0].value.messages[0].text.body
              message_type = body.entry[0].changes[0].value.messages[0].type

              # User registration prompt
              reg_buttons = [{
                "type": 'reply',
                "reply": {
                  "id": 'confirm-registration',
                  "title": 'Yes'
                }
              }, {
                "type": 'reply',
                "reply": {
                  "id": 'cancel-registration',
                  "title": 'No'
                }
              }, {
                "type": 'reply',
                "reply": {
                  "id": 'customer-relations',
                  "title": 'More info'
                }
              }]

              # User confirmation prompt
              reg_confirmation_buttons = [{
                "type": 'reply',
                "reply": {
                  "id": 'confirm-details',
                  "title": 'Confirm'
                }
              }, {
                "type": 'reply',
                "reply": {
                  "id": 'edit-details',
                  "title": 'Edit'
                }
              }, {
                "type": 'reply',
                "reply": {
                  "id": 'cancel-registration',
                  "title": 'Cancel Registration'
                }
              }]
              reg_message = "Hello #{from_name}, Do you wish to register a new WA-Pay account"
              unless user_registered || message_type != 'text'
                Requests.send_button_message(from, reg_message, reg_buttons)
              end

              if message_type == 'image' && (session.step == 1)
                wa_response = Requests.send_button_message(from, "Please confirm your details are correct\nName: Eddie",
                                             reg_confirmation_buttons)
                # session.step == 2 # update step
                puts wa_response.body
              end

              if message_type == 'interactive'
                button_id = ''

                if body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.button_reply&.id
                  button_id = body.entry[0].changes[0].value.messages[0].interactive.button_reply.id
                elsif body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.list_reply&.id
                  button_id = body.entry[0].changes[0].value.messages[0].interactive.list_reply.id
                end

                # Registration confirmation
                case button_id
                when 'confirm-registration'
                  if session.type == 'user-sign-up'
                    if session.step.zero?
                      Requests.send_text_message(from, 'Upload front picture of your national ID card')
                      session.step == 1 # update step
                    elsif session.step == 1
                      Requests.send_button_message(from, 'Please confirm your details are correct',
                                                   reg_confirmation_buttons)
                      session.step == 2 # update step
                    elsif session.step == 2
                      case button_id
                      when 'confirm-details'
                        # Register user
                        Requests.send_text_message(from, "Dear #{from_name} registration was a success")
                        Requests.send_list_message(from, from_name)
                        # TODO: kill session
                      when 'edit-details'
                        Requests.send_text_message(from, 'What details were captured wrong?')
                      when 'cancel-registration'
                        Requests.send_text_message(from, 'Registration cancelled')
                        Requests.send_contact_message(from)
                        # TODO: kill session
                      end
                    end

                  end

                  # Requests.send_text_message(from, from_name, 'your Wa-Pay account registration was successful')
                  # Requests.send_list_message(from, from_name)
                  # Cancel Registration
                when 'cancel-registration'
                  Requests.send_text_message(from,
                                             "Dear #{from_name}, thank you for checking out Wa-Pay, you can contact us for more info")
                  Requests.send_contact_message(from)
                when 'customer-relations'
                  Requests.send_text_message(from,
                                             "Dear #{from_name} thank you for checking out Wa-Pay, you can contact us for more info")
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
