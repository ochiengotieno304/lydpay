# frozen_string_literal: true

require 'mongo'
require 'active_support/core_ext/numeric/time'

module Wapay
  class Session
    def self.available?(doc_id)
      return true if collection.find({ _id: doc_id }).first

      false
    end

    def self.find_session(doc_id)
      doc = collection.find({ _id: doc_id }).first.to_json
      JSON.parse(doc, object_class: OpenStruct)
    end

    def self.update_document(doc_id, update_data)
      collection.update_one(
        { _id: doc_id },
        { '$set' => update_data }
      )
    end

    def self.update_sessions(doc_id, update_data)
      collection.update_one(
        { _id: doc_id },
        { '$set' => update_data }
      )
    end

    def self.create_session(user_id, session_type, transfer_type = nil)
      doc = if session_type == 'general'
              {
                _id: user_id,
                scope: 'general',
                name: nil,
                idNumber: nil,
                confirmed: false,
                createdAt: Time.now,
                updateAt: Time.now,
                validTill: Time.now + 10.minute
              }
            else
              {
                _id: user_id,
                scope: 'payments',
                state: 'init',
                transferType: transfer_type,
                recipientAccount: nil,
                amount: nil,
                createdAt: Time.now,
                updatedAt: Time.now,
                validTill: Time.now + 10.minute
              }
            end
      collection.insert_one(doc)
    end

    def self.delete_session(user_id)
      collection.delete_one({ _id: user_id })
    end

    def self.filter_session(filter)
      doc = collection.find(filter).first.to_json
      JSON.parse(doc, object_class: OpenStruct)
    end

    def self.init_collection
      client = Mongo::Client.new(ENV['MONGO_URI'], database: 'SessionsDB')
      begin
        @collection = client[:sessions]
      rescue Mongo::Error::OperationFailure => e
        puts e
      ensure
        client.close
      end
    end

    private_class_method def self.collection
      @collection ||= init_collection
    end
  end
end
