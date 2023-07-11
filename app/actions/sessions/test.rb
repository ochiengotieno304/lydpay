# frozen_string_literal: true

module Wapay
  module Actions
    module Sessions
      class Test < Wapay::Action
        # include Deps['sessions']

        def handle(request, response)
          request_body = request.body.read

          body = JSON.parse(request_body, object_class: OpenStruct)
          phone = body.phone

          session_availability = Session.find_session('_id', phone)
          puts session_availability

          response.body = if session_availability
                            { message: 'session loaded' }.to_json
                          else
                            { message: 'no session loaded' }.to_json
                          end
          response.status = 200
        end
      end
    end
  end
end
