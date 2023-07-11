# frozen_string_literal: true

require 'faraday'
require 'ostruct'

module Wapay
  module Actions
    module Webhook
      class Incoming < Wapay::Action
        def handle(request, response)
          user_registered = true
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

              # SOME LOGIC WAS HERE
              session_availability = Session.find_session('_id', from)
              if user_registered && session_availability

                transfer_type = session_availability.paymentSteps.transferType
                session_availability.paymentSteps.step

                case message_type
                when 'text'
                  case transfer_type
                  when 'none'
                    Requests.send_text_message(from, 'none scenario')
                    Requests.send_list_message(from, "Good afternoon #{from_name}")
                  when 'wallet-to-wallet'
                    Requests.send_text_message(from, 'wallet to wallet transfer')
                  when 'bill'
                    Requests.send_text_message(from, 'bills and shopping')
                  else
                    Requests.send_text_message(from, 'No scene')
                  end

                when 'interactive'
                  button_id = ''
                  if body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.button_reply&.id
                    button_id = body.entry[0].changes[0].value.messages[0].interactive.button_reply.id
                  elsif body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.list_reply&.id
                    button_id = body.entry[0].changes[0].value.messages[0].interactive.list_reply.id
                  end
                  case button_id
                  when 'wallet-to-wallet'
                    Requests.send_text_message(from, 'Input wallet id to send funds from')
                  when 'wallet-to-mpesa'
                    Requests.send_text_message(from, 'Input phone number to send funds to')
                  when 'wallet-to-bank'
                    Requests.send_text_message(from, 'Input card number to send funds to')
                  when 'wa-pay-business-account'
                    Requests.send_text_message(from, 'Input Wa-Pay business till number')
                  when 'buy-airtime'
                    Requests.send_text_message(from, 'Input recipient phone')
                  when 'buy-airtime'
                    Requests.send_text_message(from, 'Input recipient phone')
                  else
                    # TODO: handle interactive errors
                  end

                else
                  puts 'hello interactive'
                end
              end
            end
          else
            response.status = 404
          end
        end
      end
    end
  end
end
