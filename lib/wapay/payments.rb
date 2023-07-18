# frozen_string_literal: true

require 'stanbic'

module Wapay
  class Payments
    def self.wallet_top_up(user_id, bill_account, amount)
      bill_account_ref = '33562174'
      mpesa_checkout = client.mpesa_checkout(bill_account, amount, bill_account_ref)
      is_success = mpesa_checkout.status
      if is_success == 'Success'
        user_data = User.user_data(user_id)
        balance = user_data.balance
        balance += amount.to_i

        update_data = {
          'balance' => balance
        }

        User.update_user(user_id, update_data)
        Requests.send_text_message(user_id,
                                   "Top up of KES #{amount} was successful\nNew wallet balance is KES #{balance}")
      else
        Requests.send_text_message(user_id, "We were unable to process your KES #{amount} top up request")
      end
    end

    def self.init_client
      @client = Stanbic::Client.new(api_key: ENV['STANBIC_CLIENT_ID'], api_secret: ENV['STANBIC_CLIENT_SECRET'])
    end

    private_class_method def self.client
      @client ||= init_client
    end
  end
end
