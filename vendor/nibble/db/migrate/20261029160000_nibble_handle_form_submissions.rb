class NibbleHandleFormSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :form_submissions, :handled_at, :datetime
    add_column :form_submissions, :handled_by_id, :integer

    create_table :form_submission_notes do |t|
      t.references :form_submission, null: false, foreign_key: { on_delete: :cascade }
      t.integer :user_id
      t.text :body, null: false
      t.timestamps
    end

    create_table :form_retentions do |t|
      t.string :form, null: false
      t.integer :retention_days
      t.integer :spam_retention_days
      t.datetime :missing_since
      t.timestamps
      t.index :form, unique: true
    end
  end
end
