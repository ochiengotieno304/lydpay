# frozen_string_literal: true

require 'ostruct'

module Wapay
  module Actions
    module Webhook
      class Mpesa < Wapay::Action
        @@transaction_id = "LYD#{Time.now.strftime('%y%m%d%H%M%S%L')}"
        @@time = Time.now.strftime('%d/%m/%Y, %I:%M %p')

        def handle(request, response)
          request_body = request.body.read
          body = JSON.parse(request_body, object_class: OpenStruct)

          result_code = body.Body.stkCallback.ResultCode
          checkout_request_id = body.Body.stkCallback.CheckoutRequestID

          filter = { checkoutRequestId: checkout_request_id }
          session = Session.filter_session(filter)

          if session
            user_id = session._id
            user_balance = User.user_data(user_id).balance.to_i
            billed_account = session.recipientAccount
            if result_code.zero?
              top_up_amount = body.Body.stkCallback.CallbackMetadata.Item[0].Value.to_i
              User.update_user(user_id, { 'balance' => user_balance + top_up_amount })
              Transaction.log_transaction("M-#{billed_account}", user_id, 'wallet-top-up', top_up_amount,
                                          @@transaction_id)
              Requests.send_text_message(user_id,
                                         "Top up of KES #{top_up_amount} on #{@@time} was successful new wallet balance KES #{user_balance + top_up_amount} - #{@@transaction_id}")
            elsif result_code == 1032
              Requests.send_text_message(user_id, 'Top up canceled user')
            else
              Requests.send_text_message(user_id, 'Top up failed')
            end
            Session.delete_session(user_id)
          end

          response.status = 202
        end
      end
    end
  end
end
