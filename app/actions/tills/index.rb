# frozen_string_literal: true

module Wapay
  module Actions
    module Tills
      class Index < Wapay::Action
        include Deps['dashboard']

        def handle(*, response)
          response.body = dashboard.all_tills
        end
      end
    end
  end
end
