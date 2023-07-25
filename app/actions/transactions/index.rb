# frozen_string_literal: true

module Wapay
  module Actions
    module Transactions
      class Index < Wapay::Action
        include Deps['transactions_dashboard']

        def handle(*, response)
          response.body = transactions_dashboard.all_transactions
        end
      end
    end
  end
end
