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
              amount = session_availability.paymentSteps.amount

              case body.entry[0].changes[0].value.messages[0].type # message type
              when 'text'
                handle_text_message(from, transfer_type, step, recipient_account, body, amount)
              when 'interactive'
                handle_interactive_message(from, recipient_account, amount, body, step)
              else
                puts 'Unhandled message type'
              end
            end
          else
            response.status = 404
          end
        end

        private

        def handle_text_message(to, transfer_type, step, recipient_account, body, amount)
          message = body.entry[0].changes[0].value.messages[0].text.body

          if message.downcase == 'balance'
            Requests.send_text_message(to,
                                       "Your balance as of #{Time.now.strftime('%d %B, %Y, %I:%M %p')} was KES #{Random.rand(2000)}")
          end

          case transfer_type
          when 'none'
            Requests.send_list_message(to,
                                       "#{greeting} #{body.entry[0].changes[0].value.contacts[0].profile.name}") # profile name
          when 'wallet-to-wallet'
            handle_wallet_to_wallet(to, step, recipient_account, message, amount)
          when 'wallet-to-mpesa'
            handle_wallet_to_mpesa(to, step, recipient_account, message, amount)
          when 'wallet-to-bank'
            handle_wallet_to_bank(to, step, recipient_account, message, amount)
          when 'bill'
            Requests.send_text_message(to, 'bills and shopping')
          else
            Requests.send_text_message(to, 'No scene')
          end
        end

        def handle_wallet_to_wallet(account_id, step, recipient_account, message, amount)
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
          case step
          when 1
            Session.update_session('_id', account_id, 'paymentSteps.recipientAccount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 2)
            Requests.send_text_message(account_id, 'Amount to send')
          when 2
            Session.update_session('_id', account_id, 'paymentSteps.amount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 3)

            Requests.send_button_message(account_id, "Send Kes #{message} to Wa-Pay account #{recipient_account}",
                                         confirmation_buttons)
          when 3
            Requests.send_text_message(account_id, 'You have a pending transaction')
            Requests.send_button_message(account_id, "Send Kes #{amount} to Wa-Pay wallet #{recipient_account}",
                                         confirmation_buttons)
          else
            # TODO: handle step errors
          end
        end

        def handle_wallet_to_mpesa(account_id, step, recipient_account, message, amount)
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
          case step
          when 1
            Session.update_session('_id', account_id, 'paymentSteps.recipientAccount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 2)
            Requests.send_text_message(account_id, 'Amount to send')
          when 2
            Session.update_session('_id', account_id, 'paymentSteps.amount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 3)

            Requests.send_button_message(account_id, "Send Kes #{message} to M-Pesa account #{recipient_account}",
                                         confirmation_buttons)
          when 3
            Requests.send_text_message(account_id, 'You have a pending transaction')
            Requests.send_button_message(account_id, "Send Kes #{amount} to M-Pesa account #{recipient_account}",
                                         confirmation_buttons)
          else
            # TODO: handle step errors
          end
        end

        def handle_wallet_to_bank(account_id, step, recipient_account, message, amount)
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
          case step
          when 1
            Session.update_session('_id', account_id, 'paymentSteps.recipientAccount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 2)
            Requests.send_text_message(account_id, 'Amount to send')
          when 2
            Session.update_session('_id', account_id, 'paymentSteps.amount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 3)

            Requests.send_button_message(account_id, "Send Kes #{message} to bank account #{recipient_account}",
                                         confirmation_buttons)
          when 3
            Requests.send_text_message(account_id, 'You have a pending transaction')
            Requests.send_button_message(account_id, "Send Kes #{amount} to bank account #{recipient_account}",
                                         confirmation_buttons)
          else
            # TODO: handle errors
          end
        end

        def handle_interactive_message(session_id, recipient, amount, body, step)
          button_id = body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.button_reply&.id ||
            body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.list_reply&.id
          update_data = {
            'paymentSteps.step' => 0,
            'paymentSteps.confirmed' => false,
            'paymentSteps.recipientAccount' => 'none',
            'paymentSteps.transferType' => 'none',
            'paymentSteps.amount' => 'none',
            'timestamp' => Time.now
          }
          case button_id
          when 'wallet-to-wallet'
            Session.update_session('_id', session_id, 'paymentSteps.transferType', 'wallet-to-wallet')
            Requests.send_text_message(session_id, 'Input wallet ID to send funds to')
            Session.update_session('_id', session_id, 'paymentSteps.step', 1)
          when 'wallet-to-mpesa'
            Session.update_session('_id', session_id, 'paymentSteps.transferType', 'wallet-to-mpesa')
            Requests.send_text_message(session_id, 'Input phone number to send funds to')
            Session.update_session('_id', session_id, 'paymentSteps.step', 1)
          when 'wallet-to-bank'
            Session.update_session('_id', session_id, 'paymentSteps.transferType', 'wallet-to-bank')
            Requests.send_text_message(session_id, 'Input card number to send funds to')
            Session.update_session('_id', session_id, 'paymentSteps.step', 1)
          when 'wa-pay-business-account'
            Requests.send_text_message(session_id, 'Input Wa-Pay business till number')
          when 'buy-airtime'
            Requests.send_text_message(session_id, 'Input recipient phone')
          when 'confirm-transaction'
            if step >= 2
              Session.update_session('_id', session_id, 'paymentSteps.confirmed', true)
              Requests.send_text_message(session_id, "KES #{amount} sent to #{recipient} successfully")

              Session.update_document(session_id, update_data)
            else
              Requests.send_text_message(session_id, "No pending transactions")
              Requests.send_list_message(session_id, "#{greeting} #{body.entry[0].changes[0].value.contacts[0].profile.name}") # profile name
            end
          when 'cancel-transaction'
            if step >= 2
              Requests.send_text_message(session_id, "Transfer of KES #{amount} to #{recipient} was canceled")
              Session.update_document(session_id, update_data)
            else
              Requests.send_text_message(session_id, "No pending transactions")
              Requests.send_list_message(session_id, "#{greeting} #{body.entry[0].changes[0].value.contacts[0].profile.name}") # profile name
            end
          else
            # TODO: handle interactive errors
          end
        end

        def greeting
          h = Time.now.hour
          if h < 12
            'Good morning '
          elsif h < 18
            'Good afternoon '
          else
            'Good evening '
          end
        end
      end
    end
  end
end
