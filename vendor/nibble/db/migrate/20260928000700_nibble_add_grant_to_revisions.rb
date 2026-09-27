class NibbleAddGrantToRevisions < ActiveRecord::Migration[8.1]
  def change
    add_column "revisions", "grant_id", :integer
  end
end
