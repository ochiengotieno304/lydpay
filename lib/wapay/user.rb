# frozen_string_literal: true

require 'mongo'

module Wapay
  class User
    def self.create_user(name, phone, id_number)
      doc = {
        name:,
        phone:,
        id_number:,
        balance: 0,
        created_at: Time.now
      }

      collection.insert_one(doc)
    end

    def self.user_data(user_id)
      doc = collection.find({ phone: user_id }).first.to_json
      JSON.parse(doc, object_class: OpenStruct)
    end

    def self.update_user(user_id, update_data)
      collection.update_one(
        { 'phone' => user_id },
        { '$set' => update_data }
      )
    end

    def self.available?(phone)
      return true if collection.find({ phone: phone }).first

      false
    end

    def self.init_collection
      client = Mongo::Client.new(ENV['MONGO_URI'], database: 'UsersDB')
      begin
        @collection = client[:users]
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
