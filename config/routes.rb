# frozen_string_literal: true

module Wapay
  class Routes < Hanami::Routes
    root { 'Hello from Hanami' }
    get '/webhook', to: 'webhook.verification'
    post '/webhook', to: 'webhook.incoming'
    post '/users', to: 'users.create'
    get '/sessions/test', to: 'sessions.test'
  end
end
