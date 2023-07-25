# frozen_string_literal: true

require 'mongo'

module Wapay
  class Transaction
    def self.log_transaction(party_a, party_b, transaction_type, amount)
      doc = {
        party_a:,
        party_b:,
        transaction_type:,
        amount:,
        code: "LYD#{Time.now.strftime('%y%m%d%H%M%S%L')}",
        completed_at: Time.now
      }

      collection.insert_one(doc)
    end

    def self.transaction_data(transaction_id)
      doc = collection.find({ phone: transaction_id }).first.to_json
      JSON.parse(doc, object_class: OpenStruct)
    end

    def self.all_transactions
      transactions = []
      collection.find.each do |document|
        transactions.append(document.to_json)
      end

      transactions
    end

    def self.init_collection
      client = Mongo::Client.new(ENV['MONGO_URI'], database: 'TransactionsDB')
      begin
        @collection = client[:transactions]
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
