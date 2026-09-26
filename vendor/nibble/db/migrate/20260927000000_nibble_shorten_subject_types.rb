class NibbleShortenSubjectTypes < ActiveRecord::Migration[8.1]
  TYPES = { "Nibble::Records::Entry" => "entry", "Nibble::Records::FormSubmission" => "form_submission",
            "Nibble::Records::Webhook" => "webhook" }.freeze

  def up = shorten(TYPES)
  def down = shorten(TYPES.invert)

  private

  def shorten(types)
    %w[comments notifications].product(types.to_a).each do |table, (from, to)|
      execute "UPDATE #{table} SET subject_type = #{quote(to)} WHERE subject_type = #{quote(from)}"
    end
  end
end
