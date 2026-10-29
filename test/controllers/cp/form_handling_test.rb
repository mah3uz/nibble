require "test_helper"

class Nibble::Cp::FormHandlingTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  Submission = Nibble::Records::FormSubmission
  Audit = Nibble::Records::AuditEntry

  setup { sign_in_as users(:editor) }

  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def props = page["props"]

  def contact(data = {}, **attrs)
    Submission.create!(form: "contact", data: { "name" => "Ada", "email" => "ada@example.test", "topic" => "sales", "message" => "Hi" }.merge(data), **attrs)
  end

  def audited(action) = Audit.where(action:).order(:id).last

  test "a submission is New until someone marks it handled, who and when are kept, and it can go back to New" do
    submission = contact
    assert_not submission.handled?

    post "/cp/forms/contact/submissions/#{submission.id}/handled", params: { handled: true }
    assert submission.reload.handled?
    assert_equal users(:editor).id, submission.handled_by_id

    get "/cp/forms/contact/submissions/#{submission.id}"
    assert_equal [ true, users(:editor).name ], props["submission"].values_at("handled", "handled_by")

    post "/cp/forms/contact/submissions/#{submission.id}/handled", params: { handled: false }
    assert_not submission.reload.handled?
    assert_nil submission.handled_by_id
  end

  test "the listing filters New and Handled, and bulk actions change many at once" do
    first = contact({ "name" => "Grace" })
    second = contact({ "name" => "Ada" })

    post "/cp/actions", params: { resource: "forms.contact", handle: "mark_handled", ids: [ first.id ] }
    get "/cp/forms/contact", params: { handling: "handled" }
    assert_equal [ "Grace" ], props["listing"]["rows"].map { |row| row["name"] }
    get "/cp/forms/contact", params: { handling: "new" }
    assert_equal [ "Ada" ], props["listing"]["rows"].map { |row| row["name"] }

    post "/cp/actions", params: { resource: "forms.contact", handle: "mark_handled", ids: [ first.id, second.id ] }
    assert_equal [ true, true ], [ first, second ].map { |item| item.reload.handled? }
    post "/cp/actions", params: { resource: "forms.contact", handle: "mark_new", ids: [ first.id, second.id ] }
    assert_equal [ false, false ], [ first, second ].map { |item| item.reload.handled? }
  end

  test "opening a submission reads it, and Mark unread puts it back among the unread, singly or in bulk" do
    submission = contact
    other = contact
    get "/cp/forms/contact/submissions/#{submission.id}"
    assert submission.reload.read?

    post "/cp/forms/contact/submissions/#{submission.id}/unread"
    assert_not submission.reload.read?

    other.update!(read_at: Time.current)
    post "/cp/actions", params: { resource: "forms.contact", handle: "mark_unread", ids: [ other.id ] }
    assert_not other.reload.read?
  end

  test "a note keeps who wrote it and when, shows on the submission page and is audited without its text" do
    submission = contact
    post "/cp/forms/contact/submissions/#{submission.id}/notes", params: { body: "Called back, wants a quote." }

    note = submission.notes.sole
    assert_equal [ users(:editor).id, "Called back, wants a quote." ], [ note.user_id, note.body ]
    get "/cp/forms/contact/submissions/#{submission.id}"
    assert_equal [ "Called back, wants a quote.", users(:editor).name ], props["submission"]["notes"].first.values_at("body", "author")
    entry = audited("form.note_added")
    assert_equal [ users(:editor).id, submission.id ], [ entry.actor_id, entry.subject_id ]
    assert_not_includes entry.changeset.to_s, "quote"

    post "/cp/forms/contact/submissions/#{submission.id}/notes", params: { body: "  " }
    assert_equal 1, submission.notes.count
  end

  test "handling and notes need the edit ability; viewing alone refuses them" do
    viewer = users(:author)
    viewer.roles = [ Nibble::Role.create!(handle: "contact_viewer", title: "Contact viewer", abilities: %w[forms.contact.view]) ]
    sign_in_as viewer
    submission = contact

    post "/cp/forms/contact/submissions/#{submission.id}/handled", params: { handled: true }
    assert_response :forbidden
    post "/cp/forms/contact/submissions/#{submission.id}/notes", params: { body: "Hi" }
    assert_response :forbidden
    post "/cp/forms/contact/submissions/#{submission.id}/unread"
    assert_response :forbidden
    post "/cp/actions", params: { resource: "forms.contact", handle: "mark_handled", ids: [ submission.id ] }
    assert_response :forbidden
    assert_not submission.reload.handled?
    assert_equal 0, submission.notes.count

    get "/cp/forms/contact/submissions/#{submission.id}"
    assert_not props["can_edit"]
  end

  test "exporting and deleting submissions are audited with the form and how many" do
    contact
    contact
    get "/cp/forms/contact.csv"
    entry = audited("form.exported")
    assert_equal [ users(:editor).id, "contact", 2 ], [ entry.actor_id, entry.changeset["form"], entry.changeset["count"] ]

    post "/cp/actions", params: { resource: "forms.contact", handle: "delete", ids: Submission.ids }
    assert_equal 2, audited("form.submission_deleted").changeset["count"]

    single = contact
    delete "/cp/forms/contact/submissions/#{single.id}"
    assert_equal [ "contact", 1 ], audited("form.submission_deleted").changeset.values_at("form", "count")
  end

  test "a removed form's submissions are kept until 30 days after the form disappears, then purged" do
    Submission.create!(form: "gone", data: { "email" => "a@example.test" }, created_at: 1.year.ago)
    Nibble::Jobs::PurgeSubmissions.perform_now
    assert_equal 1, Submission.where(form: "gone").count, "the clock starts when the form is first seen missing, not at the submission's age"

    travel 29.days do
      Nibble::Jobs::PurgeSubmissions.perform_now
      assert_equal 1, Submission.where(form: "gone").count
    end
    travel 31.days do
      Nibble::Jobs::PurgeSubmissions.perform_now
      assert_equal 0, Submission.where(form: "gone").count
    end
  end

  test "a removed form keeps the retention it last had" do
    Nibble::Records::FormRetention.create!(form: "gone", retention_days: 10)
    old = Submission.create!(form: "gone", data: {}, created_at: 11.days.ago)
    fresh = Submission.create!(form: "gone", data: {}, created_at: 2.days.ago)

    Nibble::Jobs::PurgeSubmissions.perform_now
    assert_not Submission.exists?(old.id)
    assert Submission.exists?(fresh.id)
  end

  test "the purge records each live form's retention so it is known after the form is removed" do
    Nibble::Jobs::PurgeSubmissions.perform_now
    assert Nibble::Records::FormRetention.exists?(form: "contact")
  end

  test "nibble:check warns about stored submissions of a form that is no longer in the schema" do
    Submission.create!(form: "gone", data: {})
    Submission.create!(form: "gone", data: {})
    warning = Nibble::Check.run.warnings.find { |item| item.source == "form 'gone'" }
    assert_match(/2 stored submissions/, warning.message)
  end

  test "an administrator finds a person's submissions across forms, exports them and erases them with their files, auditing both" do
    sign_in_as users(:admin)
    mine = contact({ "email" => "Jane@Example.test" })
    mine.files.attach(io: StringIO.new("%PDF-1.4"), filename: "cv.pdf")
    other_form = Submission.create!(form: "gone", data: { "contact" => "please write to jane@example.test" })
    unrelated = contact({ "email" => "janet@example.test", "message" => "my friend jane@example.testing" })

    get "/cp/personal-data", params: { email: "jane@example.test" }
    assert_equal 2, props["total"]
    assert_equal [ "contact", "gone" ], props["forms"].map { |row| row["handle"] }.sort

    get "/cp/personal-data/export.json", params: { email: "jane@example.test" }
    assert_equal [ mine.id, other_form.id ].sort, JSON.parse(response.body).map { |row| row["id"] }.sort
    assert_equal 2, audited("form.person_exported").changeset["count"]
    assert_not_includes audited("form.person_exported").changeset.to_s, "jane@"

    get "/cp/personal-data/export.csv", params: { email: "jane@example.test" }
    assert_equal %w[form id created_at status field value], CSV.parse(response.body).first

    perform_enqueued_jobs { delete "/cp/personal-data", params: { email: "jane@example.test" } }
    assert_equal [ unrelated.id ], Submission.ids
    assert_equal 0, ActiveStorage::Blob.count
    erased = audited("form.person_erased")
    assert_equal [ 2, { "contact" => 1, "gone" => 1 } ], erased.changeset.values_at("count", "forms")
  end

  test "the personal data tools are for administrators and need a fresh password" do
    get "/cp/personal-data"
    assert_response :forbidden
    get "/cp/personal-data/export.json", params: { email: "ada@example.test" }
    assert_response :forbidden
    submission = contact
    delete "/cp/personal-data", params: { email: "ada@example.test" }
    assert_response :forbidden
    assert Submission.exists?(submission.id)

    sign_in_as users(:admin)
    Nibble::Current.session.update!(elevated_at: 20.minutes.ago)
    delete "/cp/personal-data", params: { email: "ada@example.test" }
    assert Submission.exists?(submission.id)
    get "/cp/personal-data/export.json", params: { email: "ada@example.test" }
    assert_not_equal 200, response.status
  end
end
