# frozen_string_literal: true

module Wapay
  class Routes < Hanami::Routes
    root { 'Hello from Hanami' }
    get '/webhook', to: 'webhook.verification'
    post '/whatsapp', to: 'webhook.wandler'
    post '/webhook/mpesa', to: 'webhook.mpesa'
    post '/users', to: 'users.create'
    get '/sessions/test', to: 'sessions.test'
    get '/users', to: 'users.index'
    patch '/users/:id', to: 'users.update'
    post '/webhook/mpesa/b2c', as: :b2c, to: ->(_env) { [202, {}, ['']] }
    post '/webhook/mpesa/b2c/queue', as: :b2c_queue, to: ->(_env) { [202, {}, ['']] }
    get '/tills', to: 'tills.index'
    post '/tills', to: 'tills.create'
    get '/sessions', to: 'sessions.index'
    get '/transactions', to: 'transactions.index'
  end
end
