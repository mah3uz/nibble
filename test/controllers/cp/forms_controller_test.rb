require "test_helper"

class Nibble::Cp::FormsControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  Submission = Nibble::Records::FormSubmission

  setup { sign_in_as users(:editor) }

  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def props = page["props"]

  def contact(data = {}, **attrs)
    Submission.create!(form: "contact", data: { "name" => "Ada", "email" => "ada@example.test", "topic" => "sales", "message" => "Hi" }.merge(data), **attrs)
  end

  test "the forms index counts real submissions per form and what's still unread; spam doesn't count" do
    contact
    contact(read_at: Time.current)
    contact(status: "spam")

    get "/cp/forms"
    row = props["forms"].find { |form| form["handle"] == "contact" }
    assert_equal [ 2, 1 ], row.values_at("submissions", "unread")
    assert_includes props["cp"]["nav"].flat_map { |section| section["items"] }.map { |item| item["title"] }, "Forms"
  end

  test "authors can't see submissions or reach the forms screens" do
    sign_in_as users(:author)
    get "/cp/forms"
    assert_response :forbidden
    get "/cp/forms/contact"
    assert_response :forbidden
  end

  test "exporting a form's submissions needs its own ability, so viewers can't take the data" do
    user = users(:author)
    user.roles = [ Role.create!(handle: "contact_only", title: "Contact only", abilities: %w[forms.contact.view]) ]
    sign_in_as user

    get "/cp/forms/contact"
    assert_response :success
    assert_not props["form"]["can_export"]

    get "/cp/forms/contact.csv"
    assert_response :forbidden
  end

  test "a form's listing hides spam unless asked, searches submitted values, and pages newest first" do
    contact({ "name" => "Grace" }, created_at: 2.days.ago)
    contact({ "name" => "Ada" }, created_at: 1.day.ago)
    contact({ "name" => "Spammer" }, status: "spam")

    get "/cp/forms/contact"
    assert_equal "cp/forms/Show", page["component"]
    listing = props["listing"]
    assert_equal [ "Ada", "Grace" ], listing["rows"].map { |row| row["name"] }
    assert_equal %w[created_at name email topic message status], listing["columns"].map { |column| column["handle"] }
    assert_equal "Sales team", listing["rows"].first["topic"]
    assert_equal [ "/cp/forms/contact/submissions/#{Submission.find_by!(status: 'received', created_at: ...1.5.days.ago).id}" ],
      [ listing["rows"].last["edit_url"] ]

    get "/cp/forms/contact", params: { status: "spam" }
    assert_equal [ "Spammer" ], props["listing"]["rows"].map { |row| row["name"] }

    get "/cp/forms/contact", params: { q: "GRACE" }
    assert_equal [ "Grace" ], props["listing"]["rows"].map { |row| row["name"] }
  end

  test "submissions export to CSV, all of them or only what the listing is filtered to" do
    contact({ "name" => "Grace" })
    contact({ "name" => "Ada" })

    get "/cp/forms/contact.csv"
    rows = CSV.parse(response.body)
    assert_equal [ "Date", "Name", "Email", "Topic", "Status" ], rows.first
    assert_equal 3, rows.size

    get "/cp/forms/contact.csv", params: { q: "grace" }
    assert_equal [ "Grace" ], CSV.parse(response.body, headers: true).map { |row| row["Name"] }
  end

  test "opening a submission marks it read and shows it as a read-only form, with its files and deliveries" do
    submission = contact({ "topic" => "support" }, deliveries: [ { "key" => "api.0", "target" => "crm", "mode" => "sync", "status" => "failed",
                                                                   "attempts" => 3, "error" => "HTTP 503" } ])

    get "/cp/forms/contact/submissions/#{submission.id}"
    assert_equal "cp/forms/Submission", page["component"]
    fields = props["blueprint"]["tabs"].first["sections"].first["fields"].map { |field| field["handle"] }
    assert_equal %w[name email topic message], fields
    assert_equal "support", props["values"]["topic"]
    assert_includes props["meta"]["topic"]["options"], { "value" => "support", "label" => "Support" }
    assert_equal [ "failed", true ], props["submission"]["deliveries"].first.values_at("status", "can_retry")
    assert submission.reload.read?

    get "/cp/forms/lead/submissions/#{submission.id}"
    assert_response :not_found, "a submission is only reachable under its own form"

    application = Submission.create!(form: "application", data: { "cv" => [ { "id" => 7, "filename" => "cv.pdf", "size" => 10 } ] })
    get "/cp/forms/application/submissions/#{application.id}"
    assert_equal [ { "filename" => "cv.pdf", "size" => 10, "url" => "/cp/forms/application/submissions/#{application.id}/files/7" } ],
      props["meta"]["cv"]["files"]
  end

  test "a failed delivery can be retried from its submission, and only a failed one" do
    submission = contact({}, deliveries: [ { "key" => "api.0", "target" => "crm", "mode" => "sync", "status" => "failed", "attempts" => 3 },
                                          { "key" => "api.1", "target" => "hook", "mode" => "async", "status" => "delivered", "attempts" => 1 } ])

    post "/cp/forms/contact/submissions/#{submission.id}/deliveries/api.0/retry"
    assert_equal "pending", submission.reload.delivery("api.0")["status"]
    assert_enqueued_with(job: Nibble::Jobs::DeliverSubmission)

    post "/cp/forms/contact/submissions/#{submission.id}/deliveries/api.1/retry"
    assert_response :bad_request
  end

  test "deleting submissions, one or in bulk, takes their files and delivery logs with them" do
    doomed = contact
    kept = contact({ "name" => "Grace" })
    doomed.files.attach(io: StringIO.new("%PDF-1.4"), filename: "cv.pdf")
    Nibble::Records::OutboundRequest.create!(owner: doomed, purpose: "form_delivery", method: "POST", url: "https://crm.example.test")

    perform_enqueued_jobs { post "/cp/actions", params: { resource: "forms.contact", handle: "delete", ids: [ doomed.id ] } }
    assert_equal [ kept.id ], Submission.ids
    assert_equal 0, ActiveStorage::Blob.count
    assert_empty Nibble::Records::OutboundRequest.all

    delete "/cp/forms/contact/submissions/#{kept.id}"
    assert_redirected_to "/cp/forms/contact"
    assert_empty Submission.all
  end

  test "the nightly purge removes submissions past their form's retention, and keeps forms without one forever" do
    old = contact({}, created_at: 31.days.ago)
    recent = contact({}, created_at: 29.days.ago)
    lead = Submission.create!(form: "lead", data: {}, created_at: 2.years.ago)

    Nibble::Jobs::PurgeSubmissions.perform_now
    assert_equal [ recent.id, lead.id ].sort, Submission.ids.sort
    assert_not Submission.exists?(old.id)
  end

  test "a new-submission notification links to the submission" do
    submission = contact
    Nibble::Records::Notification.notify(users(:editor).id, "form.submitted", subject: submission, title: "Contact", form: "contact")

    get "/cp/notifications", as: :json
    assert_equal "/cp/forms/contact/submissions/#{submission.id}", response.parsed_body["notifications"].first["url"]
  end
end
