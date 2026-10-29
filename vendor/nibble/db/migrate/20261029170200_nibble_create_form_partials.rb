class NibbleCreateFormPartials < ActiveRecord::Migration[8.1]
  def change
    create_table :form_partials do |t|
      t.string :form, null: false
      t.string :token_digest, null: false
      t.json :data, default: {}, null: false
      t.json :encrypted_data
      t.string :locale
      t.datetime :expires_at, null: false
      t.timestamps
      t.index :token_digest, unique: true
      t.index :expires_at
    end
  end
end
