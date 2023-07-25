# frozen_string_literal: true

Hanami.app.register_provider(:sessions_dashboard) do
  prepare do
  end

  start do
    dashboard = Wapay::Session

    register 'sessions_dashboard', dashboard
  end
end
