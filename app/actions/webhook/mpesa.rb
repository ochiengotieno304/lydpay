# frozen_string_literal: true

module Wapay
  module Actions
    module Webhook
      class Mpesa < Wapay::Action
        def handle(request, response)
          request_body = request.body.read

          puts request_body
          response.status = 202
        end
      end
    end
  end
end
