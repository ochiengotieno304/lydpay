# frozen_string_literal: true

require 'mongo'

module Wapay
  class Dashboard
    def self.create_user(name, phone, id_number)
      doc = {
        name:,
        phone:,
        id_number:,
        balance: 0,
        created_at: Time.now
      }

      collection('users', 'UsersDB').insert_one(doc)
    end

    def self.user_data(user_id)
      doc = collection.find({ phone: user_id }).first.to_json
      JSON.parse(doc, object_class: OpenStruct)
    end

    def self.update_user(user_id, update_data)
      collection('users', 'UsersDB').update_one(
        { 'phone' => user_id },
        { '$set' => update_data }
      )
    end

    def self.all_users
      users = []
      collection('users', 'UsersDB').find.each do |document|
        users.append(document.to_json)
      end

      users
    end

    def self.all_tills
      tills = []
      collection('tills', 'BusinessDB').find.each do |document|
        tills.append(document.to_json)
      end

      tills
    end

    def self.create_till(name, till, phone)
      doc = {
        name:,
        till:,
        phone:,
        balance: 0,
        created_at: Time.now
      }

      collection('tills', 'BusinessDB').insert_one(doc)
    end

    def self.init_collection(collection, database)
      client = Mongo::Client.new(ENV['MONGO_URI'], database:)
      begin
        @collection = client[collection]
      rescue Mongo::Error::OperationFailure => e
        puts e
      ensure
        client.close
      end
    end

    private_class_method def self.collection(collection, database)
      @collection ||= init_collection(collection, database)
    end
  end
end
