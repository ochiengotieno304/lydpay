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

          if body.object && body.entry && body.entry[0].changes &&
             body.entry[0].changes[0] && body.entry[0].changes[0].value.messages &&
             body.entry[0].changes[0].value.messages[0]

            from = body.entry[0].changes[0].value.messages[0].from

            session_availability = Session.find_session('_id', from)
            if user_registered && session_availability
              transfer_type = session_availability.paymentSteps.transferType
              step = session_availability.paymentSteps.step.to_i
              recipient_account = session_availability.paymentSteps.recipientAccount
              session_availability.paymentSteps.amount

              case body.entry[0].changes[0].value.messages[0].type
              when 'text'
                handle_text_message(from, transfer_type, step, recipient_account, body)
              when 'interactive'
                handle_interactive_message(from, transfer_type, step, body)
              else
                puts 'Unhandled message type'
              end
            end
          else
            response.status = 404
          end
        end

        private

        def handle_text_message(from, transfer_type, step, recipient_account, body)
          message = body.entry[0].changes[0].value.messages[0].text.body

          case transfer_type
          when 'none'
            Requests.send_list_message(from,
                                       "Good afternoon #{body.entry[0].changes[0].value.contacts[0].profile.name}")
          when 'wallet-to-wallet'
            handle_wallet_to_wallet(from, step, recipient_account, message)
          when 'bill'
            Requests.send_text_message(from, 'bills and shopping')
          else
            Requests.send_text_message(from, 'No scene')
          end
        end

        def handle_wallet_to_wallet(from, step, recipient_account, message)
          case step
          when 1
            Session.update_session('_id', from, 'paymentSteps.recipientAccount', message)
            Session.update_session('_id', from, 'paymentSteps.step', 2)
            Requests.send_text_message(from, 'Amount to send')
          when 2
            Session.update_session('_id', from, 'paymentSteps.amount', message)
            Session.update_session('_id', from, 'paymentSteps.step', 3)
            confirmation_buttons = [
              {
                type: 'reply',
                reply: {
                  id: 'confirm-transaction',
                  title: 'Confirm'
                }
              },
              {
                type: 'reply',
                reply: {
                  id: 'cancel-transaction',
                  title: 'Cancel'
                }
              }
            ]
            Requests.send_button_message(from, "Send Kes #{message} to #{recipient_account}", confirmation_buttons)
          else
            # TODO: handle step errors
          end
        end

        def handle_interactive_message(from, _transfer_type, _step, body)
          button_id = body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.button_reply&.id ||
                      body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.list_reply&.id

          case button_id
          when 'wallet-to-wallet'
            Requests.send_text_message(from, 'Input wallet id to send funds from')
            Session.update_session('_id', from, 'paymentSteps.transferType', 'wallet-to-wallet')
            Session.update_session('_id', from, 'paymentSteps.step', 1)
          when 'wallet-to-mpesa'
            Requests.send_text_message(from, 'Input phone number to send funds to')
          when 'wallet-to-bank'
            Requests.send_text_message(from, 'Input card number to send funds to')
          when 'wa-pay-business-account'
            Requests.send_text_message(from, 'Input Wa-Pay business till number')
          when 'buy-airtime'
            Requests.send_text_message(from, 'Input recipient phone')
          else
            # TODO: handle interactive errors
          end
        end
      end
    end
  end
end
