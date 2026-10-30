class NibbleKeepFormSubmissionLabels < ActiveRecord::Migration[8.1]
  def change
    add_column :form_submissions, :labels, :json
  end
end
