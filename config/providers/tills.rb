# frozen_string_literal: true

Hanami.app.register_provider(:tills_dashboard) do
  prepare do
  end

  start do
    dashboard = Wapay::Till

    register 'tills_dashboard', dashboard
  end
end
