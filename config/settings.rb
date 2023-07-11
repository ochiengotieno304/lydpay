# frozen_string_literal: true

module Wapay
  class Settings < Hanami::Settings
    # Define your app settings here, for example:
    #
    # setting :my_flag, default: false, constructor: Types::Params::Bool
    setting :database_url, constructor: Types::String
    setting :mongo_uri, constructor: Types::String
    setting :sessions_db, constructor: Types::String
  end
end
