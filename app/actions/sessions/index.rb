# frozen_string_literal: true

module Wapay
  module Actions
    module Sessions
      class Index < Wapay::Action
        include Deps['sessions_dashboard']

        def handle(*, response)
          response.body = sessions_dashboard.all_sessions
        end
      end
    end
  end
end
