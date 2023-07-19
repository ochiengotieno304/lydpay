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
                                   "Top up of KES #{amount} was successful. New wallet balance is KES #{balance}")
      else
        Requests.send_text_message(user_id, "We were unable to process your KES #{amount} top up request")
      end
    end

    def self.send_to_wallet(from_user_id, to_user_id, amount)
      from_account_balance = User.user_data(from_user_id).balance
      to_user_id = to_user_id[1..].rjust(12, '254') if to_user_id.start_with?('0') && (to_user_id.size == 10)
      to_account_balance = User.user_data(to_user_id).balance

      return unless from_account_balance.positive? && from_account_balance > amount.to_i

      User.update_user(from_user_id, { 'balance' => from_account_balance - amount.to_i })
      User.update_user(to_user_id, { 'balance' => to_account_balance + amount.to_i })
    end

    def self.init_client
      @client = Stanbic::Client.new(api_key: ENV['STANBIC_CLIENT_ID'], api_secret: ENV['STANBIC_CLIENT_SECRET'])
    end

    private_class_method def self.client
      @client ||= init_client
    end
  end
end
