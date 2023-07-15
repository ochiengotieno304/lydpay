# frozen_string_literal: true

module Wapay
  class Routes < Hanami::Routes
    root { 'Hello from Hanami' }
    get '/webhook', to: 'webhook.verification'
    post '/webhook', to: 'webhook.incoming'
    post '/users', to: 'users.create'
    get '/sessions/test', to: 'sessions.test'

    get '/subscriptions/:id',
        as: :subscription,
        to: ->(_env) { [200, {}, ['Subscriber 1']] }

    post '/subscribe',
         as: :subscribe,
         to: ->(_env) { [201, {}, ['Thanks!!']] }

    redirect '/home', to: '/'
  end
end
