# frozen_string_literal: true

Hanami.app.register_provider(:users_dashboard) do
  prepare do
  end

  start do
    dashboard = Wapay::User

    register 'users_dashboard', dashboard
  end
end
