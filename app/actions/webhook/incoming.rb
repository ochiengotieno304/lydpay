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
                handle_interactive_message(from, recipient_account, amount, body, step, transfer_type)
              else
                puts 'Unhandled message type'
              end
            else
              Requests.send_text_message(from, 'Not Registered')
            end
          else
            response.status = 201
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
          when 'wa-pay-business-account'
            handle_wallet_to_business(to, step, recipient_account, message, amount)
          when 'buy-airtime'
            handle_airtime_purchase(to, step, recipient_account, message, amount)
          else
            # TODO: handle transaction errors
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

            Requests.send_button_message(account_id, "Send Kes #{message} to PayChat account #{recipient_account}",
                                         confirmation_buttons)
          when 3
            Requests.send_button_message(account_id, "You have a pending transaction\nSend Kes #{amount} to PayChat wallet #{recipient_account}",
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
            Requests.send_button_message(account_id, "You have a pending transaction\nSend Kes #{amount} to M-Pesa account #{recipient_account}",
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
            Requests.send_button_message(account_id, "You have a pending transaction\nSend Kes #{amount} to bank account #{recipient_account}",
                                         confirmation_buttons)
          else
            # TODO: handle errors
          end
        end

        def handle_wallet_to_business(account_id, step, recipient_account, message, amount)
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
            Requests.send_text_message(account_id, 'Amount to top up')
          when 2
            Session.update_session('_id', account_id, 'paymentSteps.amount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 3)

            Requests.send_button_message(account_id, "Send KES #{message} to PayChat business till #{recipient_account}",
                                         confirmation_buttons)
          when 3
            Requests.send_button_message(account_id, "You have a pending transaction\nSend Kes #{amount} to PayChat business till #{recipient_account}",
                                         confirmation_buttons)
          else
            # TODO: handle errors
          end
        end

        def handle_airtime_purchase(account_id, step, recipient_account, message, amount)
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

            Requests.send_button_message(account_id, "Top up KES #{message} airtime for #{recipient_account}",
                                         confirmation_buttons)
          when 3
            Requests.send_button_message(account_id, "You have a pending transaction\nTop up KES #{amount} airtime for #{recipient_account}",
                                         confirmation_buttons)
          else
            # TODO: handle errors
          end
        end

        def handle_interactive_message(session_id, recipient, amount, body, step, transfer_type)
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
            Session.update_session('_id', session_id, 'paymentSteps.transferType', 'wa-pay-business-account')
            Requests.send_text_message(session_id, 'Input PayChat business till number')
            Session.update_session('_id', session_id, 'paymentSteps.step', 1)
          when 'buy-airtime'
            Session.update_session('_id', session_id, 'paymentSteps.transferType', 'buy-airtime')
            Requests.send_text_message(session_id, 'Input recipient phone')
            Session.update_session('_id', session_id, 'paymentSteps.step', 1)
          when 'confirm-transaction'
            if step >= 2
              Session.update_session('_id', session_id, 'paymentSteps.confirmed', true)
              if transfer_type == 'buy-airtime'
                if recipient.start_with?('0') && (recipient.size == 10)
                  AirtimeAndData.send_airtime(recipient[1..].rjust(13, '+254'), amount)
                  Requests.send_text_message(session_id,
                                             "Airtime top up of KES #{amount} to #{recipient} was successful")
                else
                  Requests.send_text_message(session_id, 'Wrong phone number format ')
                end
              else
                Requests.send_text_message(session_id, "KES #{amount} sent to #{recipient} successfully")
              end

              Session.update_document(session_id, update_data)
            else
              Requests.send_text_message(session_id, 'No pending transactions to confirm')
              Requests.send_list_message(session_id, "#{greeting} #{body.entry[0].changes[0].value.contacts[0].profile.name}") # profile name
            end
          when 'cancel-transaction'
            if step >= 2
              Requests.send_text_message(session_id, "Transfer of KES #{amount} to #{recipient} was canceled")
              Session.update_document(session_id, update_data)
            else
              Requests.send_text_message(session_id, 'No pending transactions to cancel')
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
