# frozen_string_literal: true

require 'faraday'
require 'ostruct'

module Wapay
  module Actions
    module Webhook
      class Incoming < Wapay::Action
        def handle(request, response)
          request_body = request.body.read
          body = JSON.parse(request_body, object_class: OpenStruct)

          if body.object && body.entry && body.entry[0].changes &&
             body.entry[0].changes[0] && body.entry[0].changes[0].value.messages &&
             body.entry[0].changes[0].value.messages[0]
            message_type = body.entry[0].changes[0].value.messages[0].type

            from = body.entry[0].changes[0].value.messages[0].from
            profile_name = body.entry[0].changes[0].value.contacts[0].profile.name

            user_registered = User.available?(from)

            session_availability = Session.find_session(from)
            if user_registered
              if session_availability
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
                  # TODO: handle message type errors
                end
              else
                case message_type
                when 'text'
                  Requests.send_list_message(from, "#{greeting} #{profile_name}")
                when 'interactive'
                  button_id = body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.button_reply&.id ||
                              body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.list_reply&.id

                  transfer = if %w[confirm-transaction cancel-transaction].include?(button_id)
                               'none'
                             else
                               button_id
                             end

                  Session.create_session(from, 'payments', transfer)
                else
                  # TODO: handle message type errors when no session available
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
              if message_type == 'interactive'
                if session_availability
                  step = session_availability.registrationSteps.step
                  # name = session_availability.registrationSteps.name
                  # id_number = session_availability.registrationSteps.idNumber

                  button_id = body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.button_reply&.id ||
                              body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.list_reply&.id

                  if step == 3
                    update_data = {
                      'registrationSteps.confirmed' => true,
                      'timestamp' => Time.now
                    }

                    if button_id == 'confirm-details'

                      Session.update_document(from, update_data)
                      name = session_availability.registrationSteps.name
                      id_number = session_availability.registrationSteps.idNumber
                      phone = from

                      User.create_user(name, phone, id_number)
                      Session.delete_session(from)
                      Requests.send_list_message(from, "Hi #{profile_name}, we are thrilled to have you.")
                    elsif button_id == 'cancel-registration'
                      Session.delete_session(from)
                      Requests.send_text_message(from, "Hi #{profile_name}, your registration was canceled")
                    end
                  end
                else
                  button_id = body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.button_reply&.id ||
                              body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.list_reply&.id
                  case button_id
                  when 'info-desk'
                    Requests.send_contact_message(from)
                  when 'sign-up'
                    Requests.send_text_message(from, 'Input full official names')
                    Session.create_session(from, 'general')
                  else
                    # TODO: handle errors in registartion
                  end
                end
              elsif session_availability && message_type == 'text'
                step = session_availability.registrationSteps.step
                message = body.entry[0].changes[0].value.messages[0].text.body
                case step
                when 0
                  update_name_data = {
                    'registrationSteps.step' => 1,
                    'registrationSteps.name' => message,
                    'timestamp' => Time.now
                  }
                  Session.update_document(from, update_name_data)
                  Requests.send_text_message(from, 'Input id card number')
                when 1
                  update_id_data = {
                    'registrationSteps.step' => 2,
                    'registrationSteps.idNumber' => message,
                    'timestamp' => Time.now
                  }
                  Session.update_document(from, update_id_data)
                  Requests.send_text_message(from, 'For verification, please upload id card front image')
                when 3
                  registration_buttons = [
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
                        id: 'edit-details',
                        title: 'Edit'
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
                  name = session_availability.registrationSteps.name
                  id_number = session_availability.registrationSteps.idNumber

                  Requests.send_button_message(from, "Registration pending\nConfirm details\n\nName: #{name}\nID Number: #{id_number}",
                                               registration_buttons)
                end
              elsif session_availability && message_type == 'image'
                step = session_availability.registrationSteps.step
                name = session_availability.registrationSteps.name
                id_number = session_availability.registrationSteps.idNumber
                if step == 2
                  update_data = {
                    'registrationSteps.step' => 3,
                    'timestamp' => Time.now
                  }
                  Session.update_document(from, update_data)
                  # media_id = body.entry[0].changes[0].value.messages[0].image.id
                  registration_buttons = [
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
                        id: 'edit-details',
                        title: 'Edit'
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

                  Requests.send_button_message(from, "Confirm details\n\nName: #{name}\nID Number: #{id_number}",
                                               registration_buttons)
                end
              else
                Requests.send_button_message(from, "Hi #{profile_name} , welcome to LydPay! We're so glad you're here",
                                             registration_buttons)

              end
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
                                       "Your balance as of #{Time.now.strftime('%d %B, %Y, %I:%M %p')} was KES #{User.user_data(to).balance}")
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
          when 'top-up-wallet'
            handle_mpesa_recharge(to, step, amount, message)
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
          when 0
            Requests.send_text_message(account_id, "Recipient's wallet ID")
            Session.update_session('_id', account_id, 'paymentSteps.step', 1)
          when 1
            Session.update_session('_id', account_id, 'paymentSteps.recipientAccount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 2)
            Requests.send_text_message(account_id, 'Amount to send')
          when 2
            Session.update_session('_id', account_id, 'paymentSteps.amount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 3)

            Requests.send_button_message(account_id, "Send Kes #{message} to LydPay account #{recipient_account}",
                                         confirmation_buttons)
          when 3
            Requests.send_button_message(account_id, "You have a pending transaction\nSend Kes #{amount} to LydPay wallet #{recipient_account}",
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
          when 0
            Requests.send_text_message(account_id, 'Reciepient\'s M-Pesa phone number')
            Session.update_session('_id', account_id, 'paymentSteps.step', 1)
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
          when 0
            Requests.send_text_message(account_id, 'Recipient card number')
            Session.update_session('_id', account_id, 'paymentSteps.step', 1)
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
          when 0
            Requests.send_text_message(account_id, 'Lyd-Pay till number')
            Session.update_session('_id', account_id, 'paymentSteps.step', 1)
          when 1
            Session.update_session('_id', account_id, 'paymentSteps.recipientAccount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 2)
            Requests.send_text_message(account_id, 'Amount to send')
          when 2
            Session.update_session('_id', account_id, 'paymentSteps.amount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 3)

            Requests.send_button_message(account_id, "Send KES #{message} to LydPay business till #{recipient_account}",
                                         confirmation_buttons)
          when 3
            Requests.send_button_message(account_id, "You have a pending transaction\nSend Kes #{amount} to LydPay business till #{recipient_account}",
                                         confirmation_buttons)
          else
            # TODO: handle errors
          end
        end

        def handle_mpesa_recharge(account_id, step, amount, message)
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
          when 0
            Requests.send_text_message(account_id, 'M-Pesa phone to top up from')
            Session.update_session('_id', account_id, 'paymentSteps.step', 1)
          when 1
            Session.update_session('_id', account_id, 'paymentSteps.recipientAccount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 2)
            Requests.send_text_message(account_id, 'Amount to top up')
          when 2
            Session.update_session('_id', account_id, 'paymentSteps.amount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 3)

            Requests.send_button_message(account_id, "M-Pesa account #{message} will pay KES #{amount} to Lyd Pay",
                                         confirmation_buttons)
          when 3
            Requests.send_button_message(account_id, "You have a pending transaction\nSend top up KES #{amount} to your wallet",
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
          when 0
            Requests.send_text_message(account_id, 'Amount to top up')
            Session.update_session('_id', account_id, 'paymentSteps.step', 1)
          when 1
            Session.update_session('_id', account_id, 'paymentSteps.recipientAccount', message)
            Session.update_session('_id', account_id, 'paymentSteps.step', 2)
            Requests.send_text_message(account_id, 'Amount to top up')
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

        def handle_data_bundle_purchase(account_id, step, recipient_account, message, amount)
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
          when 0
            Requests.send_text_message(account_id, 'Amount to top up')
            Session.update_session('_id', account_id, 'paymentSteps.step', 1)
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
            Requests.send_text_message(session_id, 'Input LydPay business till number')
            Session.update_session('_id', session_id, 'paymentSteps.step', 1)
          when 'buy-airtime'
            Session.update_session('_id', session_id, 'paymentSteps.transferType', 'buy-airtime')
            Requests.send_text_message(session_id, 'Input recipient phone')
            Session.update_session('_id', session_id, 'paymentSteps.step', 1)
          when 'top-up-wallet'
            Session.update_session('_id', session_id, 'paymentSteps.transferType', 'top-up-wallet')
            Requests.send_text_message(session_id, 'M-Pesa number to top up from')
            Session.update_session('_id', session_id, 'paymentSteps.step', 1)
          when 'confirm-transaction'
            if step >= 2
              Session.update_session('_id', session_id, 'paymentSteps.confirmed', true)
              if transfer_type == 'buy-airtime'
                if recipient.start_with?('0') && (recipient.size == 10)
                  AirtimeAndData.send_airtime(recipient[1..].rjust(13, '+254'), amount)
                  Requests.send_text_message(session_id,
                                             "Airtime top up of KES #{amount} to #{recipient} was successful")
                  Session.delete_session(session_id)
                else
                  Requests.send_text_message(session_id, 'Wrong phone number format ')
                end

              elsif transfer_type == 'top-up-wallet'
                session_data = Session.find_session(session_id)
                bill_account = session_data.paymentSteps.recipientAccount
                bill_amount = session_data.paymentSteps.amount
                if bill_account.start_with?('0') && (bill_account.size == 10)
                  bill_account = bill_account[1..].rjust(12, '254')
                  Payments.wallet_top_up(session_id, bill_account, bill_amount)
                else
                  Requests.send_text_message(session_id, 'Invalid phone format')
                end
                Session.delete_session(session_id)
              else
                Requests.send_text_message(session_id, "KES #{amount} sent to #{recipient} successfully")
                Session.delete_session(session_id)
              end
              Session.update_document(session_id, update_data) # TODO: send sessions to complete sessions
              Session.delete_session(session_id)
            else
              Requests.send_text_message(session_id, 'No pending transactions to confirm')
              Requests.send_list_message(session_id, "#{greeting} #{body.entry[0].changes[0].value.contacts[0].profile.name}") # profile name
            end
          when 'cancel-transaction'
            if step >= 2
              Requests.send_text_message(session_id, "Transfer of KES #{amount} to #{recipient} was canceled")
              Session.update_document(session_id, update_data) # TODO: send session to complete sessions
              Session.delete_session(session_id)
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
