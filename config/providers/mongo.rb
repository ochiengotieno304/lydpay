# frozen_string_literal: true
# # frozen_string_literal: true
#
# Hanami.app.register_provider(:mongo) do
#   prepare do
#     require 'mongo'
#   end
#
#   start do
#     client = Mongo::Client.new(target['settings'].mongo_uri, database: target['settings'].sessions_db)
#     begin
#       sessions = client[:sessions]
#       register 'sessions', sessions
#     rescue Mongo::Error::OperationFailure => e
#       puts e
#     ensure
#       client.close
#     end
#   end
# end
