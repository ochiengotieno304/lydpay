# frozen_string_literal: true

Hanami.app.register_provider(:dashboard) do
  prepare do
    ;
  end

  start do
    dashboard = Wapay::Dashboard

    register 'dashboard', dashboard

  end
end
