# frozen_string_literal: true

require 'ostruct'

module Wapay
  module Actions
    module Webhook
      class Wandler < Wapay::Action
        private

        def handle_interactive_message(user_id, request_body)
          button_id = request_body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.button_reply&.id ||
            request_body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.list_reply&.id

          session = Session.find_session(user_id)

          case button_id
          when 'wallet-to-wallet'
            Session.delete_session(user_id) if session
            Session.create_session(user_id, 'payments', 'wallet-to-wallet')
            Requests.send_text_message(user_id, 'Lyd Pay wallet number')
          when 'wallet-to-mpesa'
            Session.delete_session(user_id) if session
            Session.create_session(user_id, 'payments', 'wallet-to-mpesa')
            Requests.send_text_message(user_id, 'M-Pesa phone')
          when 'wallet-to-bank'
            Session.delete_session(user_id) if session
            Session.create_session(user_id, 'payments', 'wallet-to-bank')
            Requests.send_text_message(user_id, 'Card number')
          when 'wallet-to-till'
            Session.delete_session(user_id) if session
            Session.create_session(user_id, 'payments', 'wallet-to-till')
            Requests.send_text_message(user_id, 'Till number')
          when 'buy-airtime'
            Session.delete_session(user_id) if session
            Session.create_session(user_id, 'payments', 'buy-airtime')
            Requests.send_text_message(user_id, 'Top up amount')
          when 'confirm-transaction'
            if session
              if session.transferType == 'buy-airtime'
                Requests.send_text_message(user_id, "Top up of KES #{session.amount} was successful")
              else
                Requests.send_text_message(user_id,
                                           "Successfully sent KES #{session.amount} to #{session.recipientAccount}")
              end
              Session.delete_session(user_id)
            else
              Requests.send_text_message(user_id, 'No pending transactions to confirm')
            end
          when 'cancel-transaction'
            if session
              if session.transferType == 'buy-airtime'
                Requests.send_text_message(user_id, "Cancelled KES #{session.amount} top up request")
              else
                Requests.send_text_message(user_id,
                                           "Cancelled KES #{session.amount} transfer to #{session.recipientAccount}")
              end
              Session.delete_session(user_id)
            else
              Requests.send_text_message(user_id, 'No pending transactions to confirm')
            end
          end
        end

        def handle_wallet_to_wallet(session, message)
          user_phone = session._id
          amount = session.amount
          recipient_account = session.recipientAccount

          if recipient_account.nil?
            Session.update_sessions(user_phone, { recipientAccount: message })
            Requests.send_text_message(user_phone, 'Amount to send')
          elsif amount.nil?
            bill_amount = message
            Session.update_sessions(user_phone, { amount: bill_amount })
            Requests.send_button_message(user_phone, "Lyd-Pay wallet #{recipient_account} will receive #{bill_amount}",
                                         @@confirmation_buttons)
          else
            Requests.send_button_message(user_phone, "Pending transaction\nLyd-Pay wallet #{recipient_account} will receive KES #{amount}",
                                         @@confirmation_buttons)
          end

        end

        def handle_wallet_to_mpesa(session, message)
          user_phone = session._id
          amount = session.amount
          recipient_account = session.recipientAccount

          if recipient_account.nil?
            Session.update_sessions(user_phone, { recipientAccount: message })
            Requests.send_text_message(user_phone, 'Amount to send')
          elsif amount.nil?
            bill_amount = message
            Session.update_sessions(user_phone, { amount: bill_amount })
            Requests.send_button_message(user_phone, "M-Pesa account #{recipient_account} will receive KES #{bill_amount}",
                                         @@confirmation_buttons)
          else
            Requests.send_button_message(user_phone, "Pending transaction\nConfirm KES #{amount} transfer to M-Pesa account #{recipient_account}",
                                         @@confirmation_buttons)
          end
        end

        def handle_wallet_to_bank(session, message)
          user_phone = session._id
          amount = session.amount
          recipient_account = session.recipientAccount

          if recipient_account.nil?
            Session.update_sessions(user_phone, { recipientAccount: message })
            Requests.send_text_message(user_phone, 'Amount to send')
          elsif amount.nil?
            bill_amount = message
            Session.update_sessions(user_phone, { amount: bill_amount })
            Requests.send_button_message(user_phone, "Bank account #{recipient_account} will receive KES #{bill_amount}",
                                         @@confirmation_buttons)
          else
            Requests.send_button_message(user_phone, "Pending transaction\nConfirm KES #{amount} transfer to M-Pesa account #{recipient_account}",
                                         @@confirmation_buttons)
          end
        end

        def handle_wallet_to_till(session, message)
          user_phone = session._id
          amount = session.amount
          recipient_account = session.recipientAccount

          if recipient_account.nil?
            Session.update_sessions(user_phone, { recipientAccount: message })
            Requests.send_text_message(user_phone, 'Amount to send')
          elsif amount.nil?
            bill_amount = message
            Session.update_sessions(user_phone, { amount: bill_amount })
            Requests.send_button_message(user_phone, "Till #{recipient_account} will receive KES #{bill_amount}", # TODO replace till with business name
                                         @@confirmation_buttons)
          else
            Requests.send_button_message(user_phone, "Pending transaction\nConfirm KES #{amount} transfer to till #{recipient_account}",
                                         @@confirmation_buttons)
          end
        end

        def handle_buy_airtime(session, message)
          user_phone = session._id
          amount = session.amount
          bill_account = message

          if amount.nil?
            Session.update_sessions(user_phone, { amount: bill_account })
            Requests.send_button_message(user_phone, "Confirm KES #{bill_account} top up", @@confirmation_buttons)
          else
            Requests.send_button_message(user_phone, "Pending transaction\nConfirm KES #{amount} airtime top up",
                                         @@confirmation_buttons)
          end
        end

        def handle_text_message(session, request_body = nil)
          message = request_body.entry[0].changes[0].value.messages[0].text.body
          user_phone = request_body.entry[0].changes[0].value.messages[0].from

          if message.downcase == 'balance'
            Requests.send_text_message(user_phone,
                                       "Your balance as of #{Time.now.strftime('%d %B, %Y, %I:%M %p')} was KES #{User.user_data(user_phone).balance}")
          end

          if session
            scope = session.scope
            transfer_type = session.transferType
            session._id

            if scope == 'payments'
              case transfer_type
              when 'wallet-to-wallet'
                handle_wallet_to_wallet(session, message)
              when 'wallet-to-mpesa'
                handle_wallet_to_mpesa(session, message)
              when 'wallet-to-bank'
                handle_wallet_to_bank(session, message)
              when 'wallet-to-till'
                handle_wallet_to_till(session, message)
              when 'buy-airtime'
                handle_buy_airtime(session, message)
              end
            end
          else
            Requests.send_list_message(user_phone, greeting)
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

        @@confirmation_buttons = [
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

        protected

        def handle(request, response)
          request_body = request.body.read

          body = JSON.parse(request_body, object_class: OpenStruct)

          if body.object && body.entry && body.entry[0].changes &&
            body.entry[0].changes[0] && body.entry[0].changes[0].value.messages &&
            body.entry[0].changes[0].value.messages[0]
            message_type = body.entry[0].changes[0].value.messages[0].type

            user_phone = body.entry[0].changes[0].value.messages[0].from
            body.entry[0].changes[0].value.contacts[0].profile.name

            user_registered = true
            session = Session.find_session(user_phone)
            if user_registered
              case message_type
              when 'text'
                handle_text_message(session, body)
              when 'interactive'
                handle_interactive_message(user_phone, body)
              end
            else
              # TODO: handle unregistered user
            end
          else
            response.status = 201
          end
        end
      end
    end
  end
end
