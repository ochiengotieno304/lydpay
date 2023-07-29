# frozen_string_literal: true

module Wapay
  module Actions
    module Users
      class Update < Wapay::Action
        include Deps['users_dashboard']

        params do
          optional(:name).filled(:string)
          optional(:id_number).filled(:string)
          optional(:phone).filled(:string)
          optional(:balance).filled(:string)
          required(:id).filled(:string)
        end

        def handle(request, response)
          http_method = request.request_method
          # path_info = request.path_info
          id = request.params[:id]

          if http_method == 'PATCH'  # && path_info.match(%r{^/users/(\*)$})
            # id = ::Regexp.last_match(1)
            request_data = request.params
            hash = {}

            request_data.each { |key, value| hash[key] = value }
            result = users_dashboard.update_user_by_id(id, hash)

            if result.modified_count.to_i.positive?
              response.body = { message: 'user updated' }.to_json
              response.status = 200
            end
          else
            response.body = { error: 'user not update' }.to_json
            response.status = 200
          end
        end
      end
    end
  end
end
