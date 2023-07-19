# frozen_string_literal: true

require 'ostruct'

module Wapay
  module Actions
    module Webhook
      class Mpesa < Wapay::Action
        def handle(request, response)
          request_body = request.body.read
          body = JSON.parse(request_body, object_class: OpenStruct)
          response.status = 202
        end
      end
    end
  end
end
