# frozen_string_literal: true

Hanami.app.register_provider(:transactions_dashboard) do
  prepare do
  end

  start do
    dashboard = Wapay::Transaction

    register 'transactions_dashboard', dashboard
  end
end
