# frozen_string_literal: true

module Wapay
  module Actions
    module Users
      class Create < Wapay::Action
        include Deps['users_dashboard']

        params do
          required(:name).filled(:string)
          required(:id_number).filled(:string)
          required(:phone).filled(:string)
        end

        def handle(request, response)
          if request.params.valid?
            name = request.params[:name]
            id_number = request.params[:id_number]
            phone = request.params[:phone]

            users_dashboard.create_user(name, phone, id_number)

            response.status = 201
            response.body = { message: 'user created' }.to_json
          else
            response.status = 422
            response.format = :json
            response.body = request.params.errors.to_json
          end
        end
      end
    end
  end
end
