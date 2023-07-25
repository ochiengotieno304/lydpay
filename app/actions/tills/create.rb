# frozen_string_literal: true

module Wapay
  module Actions
    module Tills
      class Create < Wapay::Action
        include Deps['dashboard']

        params do
          required(:name).filled(:string)
          required(:till).filled(:string)
          required(:phone).filled(:string)
        end

        def handle(request, response)
          if request.params.valid?
            name = request.params[:name]
            till = request.params[:till]
            phone = request.params[:phone]

            dashboard.create_till(name, till, phone)

            response.status = 201
            response.body = { message: 'till created' }.to_json
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
