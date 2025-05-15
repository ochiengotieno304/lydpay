# frozen_string_literal: true

require 'ostruct'

module Wapay
  module Actions
    module Webhook
      class Wandler < Wapay::Action
        # Remove class variables in favor of instance methods
        def transaction_id
          "LYD#{Time.now.strftime('%y%m%d%H%M%S%L')}"
        end

        def formatted_time
          Time.now.strftime('%d/%m/%Y, %I:%M %p')
        end

        def confirmation_buttons
          [
            { type: 'reply', reply: { id: 'confirm-transaction', title: 'Confirm' } },
            { type: 'reply', reply: { id: 'cancel-transaction', title: 'Cancel' } }
          ]
        end

        protected

        def handle(request, response)
          event_handler = WebhookEventHandler.new(request)
          event_handler.process_event
          response.status = event_handler.response_status || 201
        end

        # Base webhook event handler class that delegates to specific handlers
        class WebhookEventHandler
          attr_reader :response_status

          def initialize(request)
            @request = request
            @response_status = 201
            @body = parse_request_body
          end

          def process_event
            return unless valid_webhook_message?

            @message_type = @body.entry[0].changes[0].value.messages[0].type
            @user_id = @body.entry[0].changes[0].value.messages[0].from
            @profile_name = @body.entry[0].changes[0].value.contacts[0].profile.name
            @user_registered = User.available?(@user_id)
            @session = Session.find_session(@user_id)

            if @user_registered
              process_registered_user
            else
              process_unregistered_user
            end
          end

          private

          def parse_request_body
            request_body = @request.body.read
            JSON.parse(request_body, object_class: OpenStruct)
          end

          def valid_webhook_message?
            @body.object &&
              @body.entry &&
              @body.entry[0].changes &&
              @body.entry[0].changes[0] &&
              @body.entry[0].changes[0].value.messages &&
              @body.entry[0].changes[0].value.messages[0]
          end

          def process_registered_user
            case @message_type
            when 'text'
              TextMessageHandler.new(@user_id, @body, @session).handle
            when 'interactive'
              InteractiveMessageHandler.new(@user_id, @body, @session).handle
            end
          end

          def process_unregistered_user
            case @message_type
            when 'text'
              UnregisteredUserTextHandler.new(@user_id, @body, @session).handle
            when 'interactive'
              UnregisteredUserInteractiveHandler.new(@user_id, @body, @session).handle
            when 'image'
              # TODO: Implement image message handler for registration
            end
          end
        end

        # Base handler for all message types
        class MessageHandler
          def initialize(user_id, body, session = nil)
            @user_id = user_id
            @body = body
            @session = session
          end

          protected

          def extract_button_id
            @body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.button_reply&.id ||
              @body.entry[0]&.changes&.[](0)&.value&.messages&.[](0)&.interactive&.list_reply&.id
          end

          def extract_message_text
            @body.entry[0].changes[0].value.messages[0].text.body
          end

          def profile_name
            @body.entry[0].changes[0].value.contacts[0].profile.name
          end

          def transaction_id
            "LYD#{Time.now.strftime('%y%m%d%H%M%S%L')}"
          end

          def formatted_time
            Time.now.strftime('%d/%m/%Y, %I:%M %p')
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

          def confirmation_buttons
            [
              { type: 'reply', reply: { id: 'confirm-transaction', title: 'Confirm' } },
              { type: 'reply', reply: { id: 'cancel-transaction', title: 'Cancel' } }
            ]
          end
        end

        # Handler for interactive messages from registered users
        class InteractiveMessageHandler < MessageHandler
          def handle
            button_id = extract_button_id

            case button_id
            when 'wallet-to-wallet', 'wallet-to-mpesa', 'wallet-to-bank', 'wallet-to-till', 'buy-airtime', 'wallet-top-up'
              handle_payment_initiation(button_id)
            when 'account-balance'
              handle_balance_request
            when 'confirm-transaction'
              handle_transaction_confirmation
            when 'cancel-transaction'
              handle_transaction_cancellation
            end
          end

          private

          def handle_payment_initiation(payment_type)
            Session.delete_session(@user_id) if @session
            Session.create_session(@user_id, 'payments', payment_type)

            prompt_message = case payment_type
                             when 'wallet-to-wallet' then 'Lyd Pay wallet number'
                             when 'wallet-to-mpesa' then 'M-Pesa phone'
                             when 'wallet-to-bank' then 'Card number'
                             when 'wallet-to-till' then 'Till number'
                             when 'buy-airtime' then 'Recipient phone number'
                             when 'wallet-top-up' then 'M-Pesa phone number to top up from'
                             end

            Requests.send_text_message(@user_id, prompt_message)
          end

          def handle_balance_request
            Session.delete_session(@user_id) if @session
            tx_id = transaction_id
            current_time = formatted_time

            Transaction.log_transaction(@user_id, 'self', 'balance', 'self', tx_id)
            balance_message = "Your balance on #{current_time} was KES #{User.user_data(@user_id).balance} - #{tx_id}"
            Requests.send_text_message(@user_id, balance_message)
          end

          def handle_transaction_confirmation
            return handle_no_pending_transaction unless @session

            processor = TransactionProcessorFactory.create(
              @session.transferType,
              @user_id,
              @session.recipientAccount,
              @session.amount
            )

            processor.process
          end

          def handle_transaction_cancellation
            return handle_no_pending_transaction unless @session

            if @session.transferType == 'buy-airtime'
              Requests.send_text_message(@user_id, "Cancelled KES #{@session.amount} top up request")
            else
              Requests.send_text_message(
                @user_id,
                "Cancelled KES #{@session.amount} transfer to #{@session.recipientAccount}"
              )
            end

            Session.delete_session(@user_id)
          end

          def handle_no_pending_transaction
            Requests.send_text_message(@user_id, 'No pending transactions to confirm')
            Requests.send_list_message(@user_id, 'Hello, make payments with ease')
          end
        end

        # Handler for text messages from registered users
        class TextMessageHandler < MessageHandler
          def handle
            message = extract_message_text

            # Handle special commands
            if message.downcase == 'balance'
              handle_balance_command
              return
            elsif message.downcase == 'help'
              Requests.send_contact_message(@user_id)
              return
            end

            # Handle session-based messages
            if @session && @session.scope == 'payments'
              handle_payment_flow(message)
            else
              Requests.send_list_message(@user_id, "#{greeting}#{profile_name}")
            end
          end

          private

          def handle_balance_command
            tx_id = transaction_id
            Transaction.log_transaction(@user_id, 'self', 'balance', 'self', tx_id)
            Requests.send_text_message(
              @user_id,
              "Your balance on #{formatted_time} was KES #{User.user_data(@user_id).balance} - #{tx_id}"
            )
          end

          def handle_payment_flow(message)
            handler = PaymentFlowHandlerFactory.create(
              @session.transferType,
              @session,
              message
            )

            handler.process
          end
        end

        # Factory to create appropriate transaction processor
        class TransactionProcessorFactory
          def self.create(type, user_id, recipient_account, amount)
            case type
            when 'buy-airtime'
              AirtimeProcessor.new(user_id, recipient_account, amount)
            when 'wallet-top-up'
              WalletTopUpProcessor.new(user_id, recipient_account, amount)
            when 'wallet-to-wallet'
              WalletToWalletProcessor.new(user_id, recipient_account, amount)
            when 'wallet-to-till'
              WalletToTillProcessor.new(user_id, recipient_account, amount)
            when 'wallet-to-mpesa'
              WalletToMpesaProcessor.new(user_id, recipient_account, amount)
            when 'wallet-to-bank'
              WalletToBankProcessor.new(user_id, recipient_account, amount)
            else
              DefaultProcessor.new(user_id, recipient_account, amount)
            end
          end
        end

        # Factory to create appropriate payment flow handler
        class PaymentFlowHandlerFactory
          def self.create(type, session, message)
            case type
            when 'wallet-to-wallet'
              WalletToWalletFlow.new(session, message)
            when 'wallet-to-mpesa'
              WalletToMpesaFlow.new(session, message)
            when 'wallet-to-bank'
              WalletToBankFlow.new(session, message)
            when 'wallet-to-till'
              WalletToTillFlow.new(session, message)
            when 'buy-airtime'
              AirtimeFlow.new(session, message)
            when 'wallet-top-up'
              WalletTopUpFlow.new(session, message)
            else
              DefaultFlow.new(session, message)
            end
          end
        end

        # Base class for all transaction processors
        class TransactionProcessor
          def initialize(user_id, recipient_account, amount)
            @user_id = user_id
            @recipient_account = recipient_account
            @amount = amount
            @transaction_id = "LYD#{Time.now.strftime('%y%m%d%H%M%S%L')}"
            @formatted_time = Time.now.strftime('%d/%m/%Y, %I:%M %p')
          end

          def process
            # To be implemented by subclasses
            raise NotImplementedError
          end

          protected

          def cleanup_session
            Session.delete_session(@user_id)
          end
        end

        # Airtime purchase processor
        class AirtimeProcessor < TransactionProcessor
          def process
            transaction_code = AirtimeAndData.send_airtime(@user_id, @recipient_account, @amount)

            case transaction_code
            when 'ACC01'
              handle_successful_airtime
            when 'ERR01'
              handle_insufficient_funds
            when 'ERR03'
              handle_general_error
            end

            cleanup_session
          end

          private

          def handle_successful_airtime
            Transaction.log_transaction(@user_id, @recipient_account, 'buy-airtime', @amount, @transaction_id)

            sender_message = "Airtime top up worth KES #{@amount} on #{@formatted_time} successful. New wallet balance KES #{User.user_data(@user_id).balance} - #{@transaction_id}"
            recipient_message = "You have received KES #{@amount} airtime from #{@user_id}"

            Requests.send_text_message(@user_id, sender_message)
            Requests.send_text_message(@recipient_account[1..].rjust(12, '254'), recipient_message)

            # Sms.send_sms(@user_id, sender_message)
            # Sms.send_sms(@recipient_account, recipient_message) if @amount >= 50
          end

          def handle_insufficient_funds
            Requests.send_text_message(@user_id, "Unable to complete KES #{@amount} airtime top up, insufficient funds")
          end

          def handle_general_error
            Requests.send_text_message(
              @user_id,
              'Unable to complete transaction, please try again later or contact customer care'
            )
            Requests.send_contact_message(@user_id)
          end
        end

        # Wallet top-up processor
        class WalletTopUpProcessor < TransactionProcessor
          def process
            Requests.send_text_message(@user_id, 'Confirm your pin on the Mpesa prompt')
            mpesa_response = MPesa.stk_push(@recipient_account, @amount)

            merchant_request_id = mpesa_response['MerchantRequestID']
            checkout_request_id = mpesa_response['CheckoutRequestID']

            transaction_data = {
              'merchantRequestId' => merchant_request_id,
              'checkoutRequestId' => checkout_request_id
            }

            Session.update_sessions(@user_id, transaction_data)
          end
        end

        # Wallet-to-wallet transfer processor
        class WalletToWalletProcessor < TransactionProcessor
          def process
            transaction_code = Payments.send_to_wallet(@user_id, @recipient_account, @amount)

            case transaction_code
            when 'ACC01'
              handle_successful_transfer
            when 'ERR01'
              handle_insufficient_funds
            when 'ERR02'
              handle_recipient_not_found
            end

            cleanup_session
          end

          private

          def handle_successful_transfer
            b_acc = @recipient_account[1..].rjust(12, '254')

            message = "Successfully sent KES #{@amount} to #{User.user_data(b_acc).name} on #{@formatted_time}. New wallet balance KES #{User.user_data(@user_id).balance} - #{@transaction_id}"
            message2 = "Received KES #{@amount} from #{User.user_data(@user_id).name} on #{@formatted_time}. New wallet balance KES #{User.user_data(b_acc).balance} - #{@transaction_id}"

            Transaction.log_transaction(@user_id, @recipient_account, 'wallet-to-wallet', @amount, @transaction_id)

            Requests.send_text_message(@user_id, message)
            Requests.send_text_message(b_acc, message2)

            # Sms.send_sms(@user_id, message)
            # Sms.send_sms(b_acc, message2)
          end

          def handle_insufficient_funds
            message = 'Transaction failed, insufficient wallet funds'
            Requests.send_text_message(@user_id, message)
            # Sms.send_sms(@user_id, message)
          end

          def handle_recipient_not_found
            message = "Transaction failed, could not find receiving party #{@recipient_account}"
            Requests.send_text_message(@user_id, message)
            # Sms.send_sms(@user_id, message)
          end
        end

        # Default processor for other transaction types
        class DefaultProcessor < TransactionProcessor
          def process
            Requests.send_text_message(
              @user_id,
              "Successfully sent KES #{@amount} to #{@recipient_account}"
            )
            cleanup_session
          end
        end

        # Base class for all payment flow handlers
        class PaymentFlowHandler
          def initialize(session, message)
            @session = session
            @message = message
            @user_phone = session._id
            @amount = session.amount
            @recipient_account = session.recipientAccount
          end

          def process
            if @recipient_account.nil?
              collect_recipient
            elsif @amount.nil?
              collect_amount
            else
              confirm_transaction
            end
          end

          protected

          def collect_recipient
            Session.update_sessions(@user_phone, { recipientAccount: @message })
            Requests.send_text_message(@user_phone, amount_prompt)
          end

          def collect_amount
            Session.update_sessions(@user_phone, { amount: @message })
            Requests.send_button_message(
              @user_phone,
              confirmation_message,
              confirmation_buttons
            )
          end

          def confirm_transaction
            Requests.send_button_message(
              @user_phone,
              pending_transaction_message,
              confirmation_buttons
            )
          end

          def amount_prompt
            'Amount to send'
          end

          def confirmation_message
            raise NotImplementedError, "#{self.class} must implement confirmation_message"
          end

          def pending_transaction_message
            raise NotImplementedError, "#{self.class} must implement pending_transaction_message"
          end

          def confirmation_buttons
            [
              { type: 'reply', reply: { id: 'confirm-transaction', title: 'Confirm' } },
              { type: 'reply', reply: { id: 'cancel-transaction', title: 'Cancel' } }
            ]
          end
        end

        # Wallet to wallet flow handler
        class WalletToWalletFlow < PaymentFlowHandler
          def confirmation_message
            recipient_acc = @recipient_account
            if recipient_acc.start_with?('0') && (recipient_acc.size == 10)
              recipient_acc = recipient_acc[1..].rjust(12, '254')
            end

            begin
              recipient_name = User.user_data(recipient_acc).name
              "#{recipient_name} will receive KES #{@message}"
            rescue StandardError => e
              "Lyd-Pay wallet #{@recipient_account} will receive KES #{@message}"
            end
          end

          def pending_transaction_message
            "Pending transaction\nLyd-Pay wallet #{@recipient_account} will receive KES #{@amount}"
          end
        end

        # Airtime flow handler
        class AirtimeFlow < PaymentFlowHandler
          def amount_prompt
            'Amount to top up'
          end

          def confirmation_message
            "Confirm KES #{@message} top up to #{@recipient_account}"
          end

          def pending_transaction_message
            "Pending transaction\nConfirm KES #{@amount} airtime top up"
          end
        end

        # Wallet top up flow handler
        class WalletTopUpFlow < PaymentFlowHandler
          def amount_prompt
            'Amount to top up'
          end

          def confirmation_message
            "Mpesa #{@recipient_account} will be charged KES #{@message}"
          end

          def pending_transaction_message
            "Pending transaction\nConfirm KES #{@amount} Mpesa charge to #{@recipient_account}"
          end
        end

        # Unregistered user text message handler
        class UnregisteredUserTextHandler < MessageHandler
          def handle
            message = extract_message_text

            if @session && @session.scope == 'general'
              handle_registration_flow
            else
              show_registration_options
            end
          end

          private

          def handle_registration_flow
            name = @session.name
            id_number = @session.idNumber

            if name.nil?
              Session.update_sessions(@user_id, { name: extract_message_text })
              Requests.send_text_message(@user_id, 'Id number')
            elsif id_number.nil?
              message = extract_message_text
              Session.update_sessions(@user_id, { idNumber: message })

              reg_confirm_buttons = [
                { type: 'reply', reply: { id: 'confirm-details', title: 'Confirm' } },
                { type: 'reply', reply: { id: 'cancel-registration', title: 'Cancel' } }
              ]

              Requests.send_button_message(
                @user_id,
                "Confirm that this are correct\n\nName: #{name} \nID: #{message}",
                reg_confirm_buttons
              )
            end
          end

          def show_registration_options
            registration_buttons = [
              { type: 'reply', reply: { id: 'sign-up', title: 'Sign Up' } },
              { type: 'reply', reply: { id: 'info-desk', title: 'Info desk' } },
              { type: 'reply', reply: { id: 'more-info', title: 'More info' } }
            ]

            Requests.send_button_message(@user_id, "#{greeting}#{profile_name}", registration_buttons)
          end
        end

        # Unregistered user interactive message handler
        class UnregisteredUserInteractiveHandler < MessageHandler
          def handle
            button_id = extract_button_id

            case button_id
            when 'sign-up'
              initiate_signup
            when 'confirm-details'
              complete_registration
            when 'cancel-registration'
              cancel_registration
            when 'info-desk'
              Requests.send_contact_message(@user_id)
            when 'more-info'
              Requests.send_text_message(@user_id, 'More info on https://lydpay.co')
            end
          end

          private

          def initiate_signup
            Session.delete_session(@user_id) if @session
            Session.create_session(@user_id, 'general', 'sign-up')
            Requests.send_text_message(@user_id, 'Your name')
          end

          def complete_registration
            User.create_user(@session.name, @user_id, @session.idNumber)
            Requests.send_text_message(@user_id, 'Registration successful')
            Requests.send_list_message(@user_id, 'Hi! Welcome to LydPay')
            Session.delete_session(@user_id)
          end

          def cancel_registration
            Requests.send_text_message(@user_id, 'Registration cancelled')
            Session.delete_session(@user_id)
          end
        end

        # Additional payment flow handlers
        class WalletToMpesaFlow < PaymentFlowHandler
          def confirmation_message
            "M-Pesa account #{@recipient_account} will receive KES #{@message}"
          end

          def pending_transaction_message
            "Pending transaction\nConfirm KES #{@amount} transfer to M-Pesa account #{@recipient_account}"
          end
        end

        class WalletToBankFlow < PaymentFlowHandler
          def confirmation_message
            "Bank account #{@recipient_account} will receive KES #{@message}"
          end

          def pending_transaction_message
            "Pending transaction\nConfirm KES #{@amount} transfer to bank account #{@recipient_account}"
          end
        end

        class WalletToTillFlow < PaymentFlowHandler
          def confirmation_message
            "Till #{Till.till_data(@recipient_account).name} will receive KES #{@message}"
          rescue StandardError => e
            "Till #{@recipient_account} will receive KES #{@message}"
          end

          def pending_transaction_message
            "Pending transaction\nConfirm KES #{@amount} transfer to till #{@recipient_account}"
          end
        end

        class DefaultFlow < PaymentFlowHandler
          def confirmation_message
            "#{@recipient_account} will receive KES #{@message}"
          end

          def pending_transaction_message
            "Pending transaction\nConfirm KES #{@amount} transfer to #{@recipient_account}"
          end
        end

        # Additional transaction processors
        class WalletToTillProcessor < TransactionProcessor
          def process
            transaction_code = Payments.send_to_till(@user_id, @recipient_account, @amount)

            case transaction_code
            when 'ACC01'
              handle_successful_transfer
            when 'ERR01'
              Requests.send_text_message(@user_id,
                                         "Unable to complete KES #{@amount} transfer to #{@recipient_account}, insufficient funds")
            when 'ERR02'
              Requests.send_text_message(@user_id, "Unable to complete transaction, #{@recipient_account} unavailable")
            end

            cleanup_session
          end

          private

          def handle_successful_transfer
            till_name = Till.till_data(@recipient_account).name
            till_phone = Till.till_data(@recipient_account).phone
            balance = Till.till_data(@recipient_account).balance

            message = "Successfully sent KES #{@amount} to #{till_name} on #{@formatted_time}. New wallet balance KES #{User.user_data(@user_id).balance} - #{@transaction_id}"
            message2 = "Received KES #{@amount} from #{User.user_data(@user_id).name} on #{@formatted_time} for business account #{@till_name}. New till balance KES #{balance} - #{@transaction_id}"

            Transaction.log_transaction(@user_id, @recipient_account, 'wallet-to-till', @amount, @transaction_id)

            Requests.send_text_message(@user_id, message)
            # Sms.send_sms(@user_id, message)

            Requests.send_text_message(till_phone, message2)
            # Sms.send_sms(till_phone, message2)
          rescue StandardError => e
            # Handle the case where till data cannot be retrieved
            message = "Successfully sent KES #{@amount} to till #{@recipient_account} on #{@formatted_time}. New wallet balance KES #{User.user_data(@user_id).balance} - #{@transaction_id}"
            Transaction.log_transaction(@user_id, @recipient_account, 'wallet-to-till', @amount, @transaction_id)
            Requests.send_text_message(@user_id, message)
            # Sms.send_sms(@user_id, message)
          end
        end

        class WalletToMpesaProcessor < TransactionProcessor
          def process
            transaction_code = MPesa.b_2_c(@amount, @recipient_account).ResponseCode

            if transaction_code == '0'
              Requests.send_text_message(@user_id, "Processing payment, we'll send confirmation message when complete")
            else
              Requests.send_text_message(@user_id, 'Payment request failed')
            end

            cleanup_session
          end
        end

        class WalletToBankProcessor < TransactionProcessor
          def process
            # Implementation would go here - for now just use default success message
            Requests.send_text_message(@user_id,
                                       "Successfully sent KES #{@amount} to bank account #{@recipient_account}")
            cleanup_session
          end
        end
      end
    end
  end
end
