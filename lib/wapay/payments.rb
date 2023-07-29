# frozen_string_literal: true

module Wapay
  class Payments
    def self.wallet_top_up(user_id, bill_account, amount)
      bill_account_ref = '33562174'
      mpesa_checkout = client.mpesa_checkout(bill_account, amount, bill_account_ref)
      is_success = mpesa_checkout.status
      if is_success == 'Success'
        user_data = User.user_data(user_id)
        balance = user_data.balance.to_i
        balance += amount.to_i

        update_data = {
          'balance' => balance
        }

        User.update_user(user_id, update_data)
        message = "Top up of KES #{amount} was successful. New wallet balance is KES #{balance}"
        Requests.send_text_message(user_id,
                                   message)
        Sms.send_sms(user_id, message)
      else
        Requests.send_text_message(user_id, "We were unable to process your KES #{amount} top up request")
      end
    end

    def self.send_to_wallet(from_user_id, to_user_id, amount)
      from_account_balance = User.user_data(from_user_id).balance.to_i
      to_user_id = to_user_id[1..].rjust(12, '254') if to_user_id.start_with?('0') && (to_user_id.size == 10)

      recipient_available = User.available?(to_user_id)
      if recipient_available
        to_account_balance = User.user_data(to_user_id).balance.to_i
        if from_account_balance > amount.to_i
          User.update_user(from_user_id, { 'balance' => from_account_balance - amount.to_i })
          User.update_user(to_user_id, { 'balance' => to_account_balance + amount.to_i })
          'ACC01' # successful transfer
        else
          'ERR01' # insufficient funds
        end
      else
        'ERR02' # recipient unavailable
      end
    end

    def self.send_to_till(from_user_id, till_number, amount)
      from_account_balance = User.user_data(from_user_id).balance.to_i
      till_is_available = Till.available?(till_number)

      if till_is_available
        till_balance = Till.till_data(till_number).balance.to_i

        if from_account_balance > amount.to_i
          User.update_user(from_user_id, { 'balance' => from_account_balance - amount.to_i })
          Till.update_till(till_number, { 'balance' => till_balance + amount.to_i })
          'ACC01'
        else
          'ERR01' # insufficient funds
        end
      else
        'ERR02'
      end
    end
  end
end
