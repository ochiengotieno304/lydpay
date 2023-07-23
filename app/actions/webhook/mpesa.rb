# frozen_string_literal: true

require 'ostruct'

module Wapay
  module Actions
    module Webhook
      class Mpesa < Wapay::Action
        def handle(request, response)
          request_body = request.body.read
          body = JSON.parse(request_body, object_class: OpenStruct)

          result_code = body.Body.stkCallback.ResultCode
          checkout_request_id = body.Body.stkCallback.CheckoutRequestID

          filter = { checkoutRequestId: checkout_request_id }
          session = Session.filter_session(filter)

          if session
            user_id = session._id
            user_balance = session.balance.to_i
            if result_code.zero?
              top_up_amount = body.Body.stkCallback.CallbackMetadata.Item[0].Value.to_i
              Session.update_sessions(user_id, { 'balance' => user_balance + top_up_amount })
              Requests.send_text_message(user_id,
                                         "Top up of KES #{top_up_amount} successful new wallet balance #{user_balance + top_up_amount}")
              Session.delete_session(user_id)
            elsif result_code == 1032
              Requests.send_text_message(user_id, 'Top up request failed')
              Session.delete_session(user_id)
            end
          end

          response.status = 202
        end
      end
    end
  end
end
