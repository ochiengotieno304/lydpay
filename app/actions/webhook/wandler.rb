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
          when 'wallet-top-up'
            Session.delete_session(user_id) if session
            Session.create_session(user_id, 'payments', 'wallet-top-up')
            Requests.send_text_message(user_id, 'M-Pesa phone number to top up from')
          when 'account-balance'
            Requests.send_text_message(user_id,
                                       "Your balance as of #{@@time} was KES #{User.user_data(user_id).balance}")
          when 'confirm-transaction'
            if session
              transfer_type = session.transferType
              bill_amount = session.amount
              bill_account = session.recipientAccount

              case transfer_type
              when 'buy-airtime'
                Requests.send_text_message(user_id, "Top up of KES #{session.amount} was successful")
              when 'wallet-top-up'
                Requests.send_text_message(user_id, 'Confirm your pin on the Mpesa prompt')
                MPesa.stk_push(bill_account, bill_amount)
              when 'wallet-to-wallet'
                if Payments.send_to_wallet(user_id, bill_account, bill_amount)
                  bill_account = bill_account[1..].rjust(12, '254') if bill_account.start_with?('0') && (bill_account.size == 10)
                  Requests.send_text_message(user_id,
                                             "Successfully sent KES #{bill_amount} to #{User.user_data(bill_account).name} on #{@@time}. New wallet balance KES #{User.user_data(user_id).balance}")
                  Requests.send_text_message(bill_account, "Received KES #{bill_amount} from #{User.user_data(user_id).name} on #{@@time}. New wallet balance was KES #{User.user_data(bill_account).balance} " )
                else
                  Requests.send_text_message(user_id,
                                             "Unable to complete KES #{bill_amount} transfer to #{bill_account}")
                end
              when 'wallet-to-till'
                if Payments.send_to_till(user_id, bill_account, bill_amount)
                  Requests.send_text_message(user_id,
                                             "Successfully sent KES #{bill_amount} to #{Till.till_data(bill_account).name} on #{@@time}. New wallet balance KES #{User.user_data(user_id).balance}")
                else
                  Requests.send_text_message(user_id,
                                             "Unable to complete KES #{bill_amount} transfer to #{bill_account}")
                end
              else
                Requests.send_text_message(user_id,
                                           "Successfully sent KES #{session.amount} to #{session.recipientAccount}")
              end
              Session.delete_session(user_id)
            else
              Requests.send_text_message(user_id, 'No pending transactions to confirm')
              Requests.send_list_message(user_id, 'Hello, make payments with ease')
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
              Requests.send_text_message(user_id, 'No pending transactions to cancel')
              Requests.send_list_message(user_id, 'Hello, make payments with ease')
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
            if recipient_account.start_with?('0') && (recipient_account.size == 10)
              recipient_account = recipient_account[1..].rjust(12,
                                                               '254')
            end
            Requests.send_button_message(user_phone, "#{User.user_data(recipient_account).name} will receive KES #{bill_amount}",
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
            Requests.send_button_message(user_phone, "Till #{Till.till_data(recipient_account).name} will receive KES #{bill_amount}", # TODO: replace till with business name
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

        def handle_wallet_top_up(session, message)
          user_phone = session._id
          amount = session.amount
          recipient_account = session.recipientAccount

          if recipient_account.nil?
            Session.update_sessions(user_phone, { recipientAccount: message })
            Requests.send_text_message(user_phone, 'Amount to top up')
          elsif amount.nil?
            bill_amount = message
            Session.update_sessions(user_phone, { amount: bill_amount })
            Requests.send_button_message(user_phone, "Mpesa #{recipient_account} will be charged KES #{bill_amount}",
                                         @@confirmation_buttons)
          else
            Requests.send_button_message(user_phone, "Pending transaction\nConfirm KES #{amount} Mpesa charge#{recipient_account}",
                                         @@confirmation_buttons)
          end
        end

        def handle_text_message(session, request_body = nil)
          message = request_body.entry[0].changes[0].value.messages[0].text.body
          user_phone = request_body.entry[0].changes[0].value.messages[0].from
          profile_name = request_body.entry[0].changes[0].value.contacts[0].profile.name

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
              when 'wallet-top-up'
                handle_wallet_top_up(session, message)
              end
            end
          else
            Requests.send_list_message(user_phone, "#{greeting}#{profile_name}")
          end
        end

        def handle_unregistered_user_text_message(session, request_body = nil)
          reg_confirm_buttons = [
            {
              type: 'reply',
              reply: {
                id: 'confirm-details',
                title: 'Confirm'
              }
            },
            {
              type: 'reply',
              reply: {
                id: 'cancel-registration',
                title: 'Cancel'
              }
            }
          ]
          message = request_body.entry[0].changes[0].value.messages[0].text.body
          user_phone = request_body.entry[0].changes[0].value.messages[0].from
          profile_name = request_body.entry[0].changes[0].value.contacts[0].profile.name

          if session
            scope = session.scope
            name = session.name
            id_number = session.idNumber

            if scope == 'general'
              if name.nil?
                Session.update_sessions(user_phone, { name: message })
                Requests.send_text_message(user_phone, 'Id number')
              elsif id_number.nil?
                Session.update_sessions(user_phone, { idNumber: message })
                Requests.send_button_message(user_phone,
                                             "Confirm that this are correct\n\nName: #{name} \nID: #{message}", reg_confirm_buttons)
              end
            end
          else
            registration_buttons = [
              {
                type: 'reply',
                reply: {
                  id: 'sign-up',
                  title: 'Sign Up'
                }
              },
              {
                type: 'reply',
                reply: {
                  id: 'info-desk',
                  title: 'Info desk'
                }
              },
              {
                type: 'reply',
                reply: {
                  id: 'more-info',
                  title: 'More info'
                }
              }
            ]

            Requests.send_button_message(user_phone, "#{greeting}#{profile_name}", registration_buttons)
          end
        end

        def handle_unregistered_user_interactive_message(user_id, request_body)
          button_id = request_body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.button_reply&.id ||
                      request_body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.list_reply&.id

          session = Session.find_session(user_id)

          case button_id
          when 'sign-up'
            Session.delete_session(user_id) if session
            Session.create_session(user_id, 'general', 'sign-up')
            Requests.send_text_message(user_id, 'Your name')
          when 'confirm-details'
            User.create_user(session.name, user_id, session.idNumber)
            Requests.send_text_message(user_id, 'Registration successful')
            Session.delete_session(user_id)
          when 'cancel-registration'
            Requests.send_text_message(user_id, 'Registration cancelled')
            Session.delete_session(user_id)
          when 'info-desk'
            Requests.send_contact_message(user_id)
          when 'more-info'
            Requests.send_text_message(user_id, 'More info on https://lydpay.co')
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

        @@time = Time.now.strftime('%d %B, %Y, %I:%M %p')

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

            user_registered = User.available?(user_phone)

            session = Session.find_session(user_phone)
            if user_registered
              case message_type
              when 'text'
                handle_text_message(session, body)
              when 'interactive'
                handle_interactive_message(user_phone, body)
              end
            else
              case message_type
              when 'text'
                handle_unregistered_user_text_message(session, body)
              when 'interactive'
                handle_unregistered_user_interactive_message(user_phone, body)
              when 'image'
                # TODO: handle_unregistered_user_image_message(session, body)
              end
            end
          else
            response.status = 201
          end
        end
      end
    end
  end
end
