class NibbleEncryptFormFields < ActiveRecord::Migration[8.1]
  def change
    add_column :form_submissions, :encrypted_data, :json
  end
end
