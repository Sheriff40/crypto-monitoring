class CreateSubscriptionRules < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_rules do |t|
      t.string :customer_id, null: false
      t.string :currency_symbol, null: false
      t.decimal :threshold_value, precision: 20, scale: 8, null: false
      t.integer :direction, null: false

      t.timestamps
    end

    add_index :subscription_rules, :currency_symbol
  end
end
