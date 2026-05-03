# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_03_163058) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "subscription_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency_symbol", null: false
    t.string "customer_id", null: false
    t.integer "direction", null: false
    t.decimal "threshold_value", precision: 20, scale: 8, null: false
    t.datetime "updated_at", null: false
    t.index ["currency_symbol"], name: "index_subscription_rules_on_currency_symbol"
  end
end
