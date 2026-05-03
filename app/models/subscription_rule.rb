class SubscriptionRule < ApplicationRecord
  enum :direction, { below: 0, above: 1 }, default: :below

  validates :customer_id, presence: true
  validates :currency_symbol, presence: true
  validates :threshold_value, presence: true
  validates :direction, presence: true
end
