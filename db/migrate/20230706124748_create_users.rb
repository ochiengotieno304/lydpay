# frozen_string_literal: true

ROM::SQL.migration do
  change do
    run 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'

    create_table :users do
      primary_key :id, :uuid, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      column :username, :text, null: false, unique: true
      column :phone, :text, null: false, unique: true
      column :email, :text, null: false, unique: true
    end
  end
end
