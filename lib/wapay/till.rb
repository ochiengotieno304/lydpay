# frozen_string_literal: true

require 'mongo'

module Wapay
  class Till
    def self.available?(till_no)
      return true if collection.find({ till: till_no }).first

      false
    end

    def self.create_till(name, till, phone)
      doc = {
        name:,
        till:,
        phone:,
        balance: 0,
        created_at: Time.now
      }

      collection.insert_one(doc)
    end

    def self.update_till(till_number, update_data)
      collection.update_one(
        { 'till' => till_number },
        { '$set' => update_data }
      )
    end

    def self.all_tills
      tills = []
      collection.find.each do |document|
        tills.append(document.to_json)
      end

      tills
    end

    def self.till_data(till_number)
      doc = collection.find({ till: till_number }).first.to_json
      JSON.parse(doc, object_class: OpenStruct)
    end

    def self.init_collection
      client = Mongo::Client.new(ENV['MONGO_URI'], database: 'BusinessDB')
      begin
        @collection = client[:tills]
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
