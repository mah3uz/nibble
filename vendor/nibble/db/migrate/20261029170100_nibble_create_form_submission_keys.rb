class NibbleCreateFormSubmissionKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :form_submission_keys do |t|
      t.references :form_submission, null: false, foreign_key: { on_delete: :cascade }
      t.string :form, null: false
      t.string :field, null: false
      t.string :digest, null: false
      t.index [ :form, :field, :digest ], unique: true
    end
  end
end
