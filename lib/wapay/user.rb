# frozen_string_literal: true

require 'mongo'

module Wapay
  class User

    def self.create_user(name, phone, id_number)
      doc = {
        name: name,
        phone: phone,
        id_number: id_number,
        created_at: Time.now
      }

      collection.insert_one(doc)
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
