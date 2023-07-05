# frozen_string_literal: true

module Wapay
  module Actions
    module Webhook
      class Verification < Wapay::Action

        params do
          required(:"hub.verify_token").filled(:string)
          required(:"hub.mode").filled(:string)
          required(:"hub.challenge").filled(:string)
        end



        def handle(request, response)
          token = "TOKEN"
          halt 422 unless request.params.valid?
          mode = request.params[:"hub.mode"]
          verify_token = request.params[:"hub.verify_token"]
          challenge = request.params[:"hub.challenge"]
          puts("#{verify_token == token}")
          puts("#{token} #{verify_token}")
          # halt 403 unless mode === "subscribe" and verify_token === @token

          response.status = 200
          response.body = challenge.to_i
        end
      end
    end
  end
end
