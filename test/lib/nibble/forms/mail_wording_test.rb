require "test_helper"

class Nibble::Forms::MailWordingTest < ActiveSupport::TestCase
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  setup do
    configure_nibble_records(locales: [ { "code" => "en", "default" => true }, { "code" => "fr" } ])
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { @store ||= ActiveSupport::Cache::MemoryStore.new }
    @nibble_themes.join("records/schema/forms/notice.yml").write({
      "title" => "Notice", "notify" => [ { "to" => "staff@example.test" }, { "to" => "{field.email}" } ],
      "fields" => [ { "handle" => "email", "field" => { "type" => "text", "input_type" => "email", "required" => true } } ]
    }.to_yaml)
    Nibble.reset_schema!
    I18n.backend.store_translations(:fr, nibble: { forms: { mail: { submission: { visitor_heading: "Votre envoi", staff_heading: "Nouvel envoi" } } } })
    I18n.config.clear_available_locales_set
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    Nibble::Forms::Submit.rate_limit_store = @rate_limit_store
    I18n.backend.reload!
    I18n.config.clear_available_locales_set
  end

  test "the visitor's email follows the submission's locale and staff's stays in the site's default" do
    Nibble::Forms::Submit.call(Nibble::Forms.find("notice"), { "email" => "ada@example.test" }, ip: "203.0.113.5", user_agent: "test", locale: "fr")
    perform_enqueued_jobs(only: Nibble::Jobs::NotifySubmission)

    visitor = ActionMailer::Base.deliveries.find { |mail| mail.to.include?("ada@example.test") }
    staff = ActionMailer::Base.deliveries.find { |mail| mail.to.include?("staff@example.test") }

    assert_includes visitor.text_part.body.to_s, "Votre envoi"
    assert_includes staff.text_part.body.to_s, "New submission"
    assert_not_includes staff.text_part.body.to_s, "Nouvel envoi"
  end
end
