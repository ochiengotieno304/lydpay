# frozen_string_literal: true

module Wapay
  class Routes < Hanami::Routes
    root { 'Hello from Hanami' }
    get '/webhook', to: 'webhook.verification'
    # post '/webhook', to: 'webhook.incoming'
    post '/webhook', to: 'webhook.wandler'
    post '/webhook/mpesa', to: 'webhook.mpesa'
    post '/users', to: 'users.create'
    get '/sessions/test', to: 'sessions.test'
    post '/webhook/mpesa/b2c',
         as: :b2c,
         to: ->(env) { [202, {}, ['']] }
    post '/webhook/mpesa/b2c/queue',
         as: :b2c_queue,
         to: ->(env) { [202, {}, ['']] }
    get "/users", to: "users.index"
    patch "/users/:id", to: "users.update"
  end
end
