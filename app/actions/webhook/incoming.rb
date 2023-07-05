# frozen_string_literal: true

module Wapay
  module Actions
    module Webhook
      class Incoming < Wapay::Action
        def handle(*, response)
          response.body = self.class.name
        end
      end
    end
  end
end
