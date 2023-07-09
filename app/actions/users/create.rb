# frozen_string_literal: true

module Wapay
  module Actions
    module Users
      class Create < Wapay::Action
        def handle(*, response)
          response.body = self.class.name
        end
      end
    end
  end
end
