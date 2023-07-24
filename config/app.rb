# frozen_string_literal: true

require 'hanami'
require 'rack/cors'

module Wapay
  class App < Hanami::App
    config.middleware.use :body_parser, :json
    config.middleware.use Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: %i[get post options patch delete]
      end
    end
  end
end
