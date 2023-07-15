# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Routes' do
  let(:router) { Wapay::App.router }

  it 'routes to root URL' do
    expect(router.path(:root)).to eq('/')
  end

  it 'routes to /subscribe URL' do
    expect(router.path(:subscribe)).to eq('/subscribe')
  end

  it 'recognizes "GET /subscriptions/:id"' do
    route = router.recognize('/subscriptions/1')
    aggregate_failures do
      expect(route).to be_routable
      expect(route.path).to eq('/subscriptions/1')
      expect(route.verb).to eq('GET')
      expect(route.params).to eq({ id: '1' })
    end
  end

  it 'redirects /home to /' do
    route = router.recognize('/home')

    aggregate_failures do
      expect(route.routable?).to be(true)
      expect(route.redirect?).to be(true)
      expect(route.endpoint).to be(nil)
      expect(route.redirection_path).to eq('/')
    end
  end
end
