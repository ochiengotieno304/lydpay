# frozen_string_literal: true

require 'mongo'

module Wapay
  class Session
    def self.available?(key, value)
      return true if collection.find({ "#{key}": value }).first

      false
    end

    def self.find_session(key, value)
      doc = collection.find({ "#{key}": value }).first.to_json
      JSON.parse(doc, object_class: OpenStruct)
    end

    def self.update_session(key, value, key1, value1)
      collection.update_one({ "#{key}": value }, { '$set' => { key1.to_s => value1 } })
    end

    def self.update_document(doc_id, update_data)
      collection.update_one(
        { "_id": doc_id },
        { '$set' => update_data }
      )
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
