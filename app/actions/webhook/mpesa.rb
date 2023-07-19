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
          amount = body.Body.stkCallback.CallbackMetadata.Item[0].Value
          phone_number = body.Body.stkCallback.CallbackMetadata.Item[4].Value

          if result_code.zero?
            puts 'SUCCESS' * 3
            puts "#{amount} #{phone_number}"
          end

          response.status = 202
        end
      end
    end
  end
end
