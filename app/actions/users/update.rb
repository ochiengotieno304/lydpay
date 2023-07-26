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
          request.params[:name] || nil
          request.params[:id_number] || nil
          request.params[:phone] || nil
          request.params[:balance] || nil

          puts request.params

          response.body = self.class.name
        end
      end
    end
  end
end
