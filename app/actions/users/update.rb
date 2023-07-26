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
        end

        def handle(request, response)
          name = request.params[:name] || nil
          id_number = request.params[:id_number] || nil
          phone = request.params[:phone] || nil
          balance = request.params[:balance] || nil

          response.body = self.class.name
        end
      end
    end
  end
end
