# frozen_string_literal: true

module Wapay
  module Actions
    module Users
      class Index < Wapay::Action
        include Deps['dashboard']

        def handle(*, response)
          response.body = dashboard.all_users
        end
      end
    end
  end
end
