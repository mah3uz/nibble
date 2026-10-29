require "test_helper"

class Nibble::Cp::ApprovalsControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup do
    Nibble::AgentAccess.update!(enabled: true, areas: { "entries.articles" => { "read" => true, "write" => true, "publish" => true },
                                                        "navigation" => { "read" => true, "write" => true } })
    @grant = grant("everything")
    @entry = create_entry("articles", { "title" => "Ready" }, actor: users(:admin))
  end

  def grant(preset, kind: "app", **extra) = Nibble::Grant.create!(user: users(:admin), oauth_client: Nibble::OauthClient.cli, kind:, name: "Claude",
    preset:, abilities: Nibble::AgentAccess.preset(preset == "draft" ? "draft" : "everything"), expires_at: 1.day.from_now, **extra)

  def run_op(name, input, grant: @grant)
    principal = Nibble::Principal.new(user: grant.user, grant:)
    Nibble::Operations.call(name, input, caller: Nibble::Operations::Caller.new(principal:, site: "https://example.com", ip: "127.0.0.1"))
  rescue Nibble::Operations::Failure => failure
    failure
  end

  def publish(entry = @entry, grant: @grant, **extra) = run_op("transition_entry", { "id" => entry.id, "action" => "publish" }.merge(extra.stringify_keys), grant:)

  def decide(id, decision = "approve") = patch("/cp/approvals/#{id}", params: { decision: })

  def approval(id) = Nibble::Approval.find_by!(public_id: id)

  test "approving makes the change at once, and the app gets that result without making it again" do
    asked = publish
    assert_equal "approval_required", asked.code
    assert_equal "draft", @entry.reload.status, "nothing goes live until a person says so"
    assert_match "/cp/approvals/", asked.details["approval_url"]
    assert_match "Nothing more to send", asked.hint
    assert Nibble::Records::Notification.exists?(user_id: users(:admin).id, kind: "apps.approval_requested")
    assert_equal asked.details["approval"], publish.details["approval"], "asking again doesn't pile up requests"

    sign_in_as users(:admin)
    decide(asked.details["approval"])

    assert_equal "published", @entry.reload.status, "approving carries the change out; the app doesn't have to come back"
    assert_equal "done", approval(asked.details["approval"]).status
    revisions = Nibble::Records::Revision.count
    assert_equal "published", publish(approval: asked.details["approval"])["status"], "a client that resends with the id gets the stored result"
    assert_equal revisions, Nibble::Records::Revision.count, "and nothing changes again"
  end

  test "a finished approval doesn't answer a new request for the same change" do
    asked = publish
    sign_in_as users(:admin)
    decide(asked.details["approval"])
    Nibble::Lifecycle.call(@entry.reload, :unpublish, {}, actor: users(:admin))

    again = publish
    assert_equal "approval_required", again.code, "publishing again is a new request, not a replay of the first"
    assert_not_equal asked.details["approval"], again.details["approval"]
    assert_not_equal "published", @entry.reload.status
  end

  test "an app retrying with its idempotency key gets the approved result, not a second request" do
    asked = publish(idempotency_key: "publish-ready")
    sign_in_as users(:admin)
    decide(asked.details["approval"])
    revisions = Nibble::Records::Revision.count

    assert_equal "published", publish(idempotency_key: "publish-ready")["status"]
    assert_equal "published", publish(idempotency_key: "publish-ready")["status"]
    assert_equal 1, @grant.approvals.count
    assert_equal revisions, Nibble::Records::Revision.count
  end

  test "a change interrupted part way is reported as failed, never as still in progress" do
    asked = publish
    approval(asked.details["approval"]).update!(status: "approved", decided_at: 11.minutes.ago)

    checked = run_op("get_approval", { "approval" => asked.details["approval"] })
    assert_equal [ "failed", "interrupted" ], [ checked["status"], checked["error"]["code"] ]
    assert_match "may not have been made", checked["error"]["message"]
    sign_in_as users(:admin)
    get "/cp/approvals/#{asked.details['approval']}"
    props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]
    assert_equal [ "failed", "interrupted" ], [ props["status"], props["error"]["code"] ]
    assert_equal "approved", approval(asked.details["approval"]).status, "nothing retries it"
  end

  test "approving twice at once makes the change once" do
    run_op("update_navigation", { "handle" => "main", "lock_version" => 0, "tree" => [] }, grant: grant("everything", kind: "ci"))
    asked = run_op("update_navigation", { "handle" => "main", "lock_version" => 0, "tree" => [ { "type" => "url", "title" => "A", "url" => "/a" } ] })
    first = approval(asked.details["approval"])
    second = approval(asked.details["approval"])

    Nibble::Operations.carry_out(first, site: "https://example.com", ip: "127.0.0.1")
    outcome = Nibble::Operations.carry_out(second, site: "https://example.com", ip: "127.0.0.1")

    assert_equal [ "done", nil ], [ outcome.status, outcome.error ], "a second run would have hit a lock conflict and recorded it"
    assert_equal 1, Nibble::Records::NavigationTree.find_by(handle: "main").lock_version
  end

  test "a declined request never happens, and the app is told it was declined" do
    asked = publish
    sign_in_as users(:admin)
    decide(asked.details["approval"], "deny")
    decide(asked.details["approval"])

    assert_equal "draft", @entry.reload.status
    assert_equal "denied", approval(asked.details["approval"]).status, "a decision can't be changed afterwards"
    assert_equal "approval_denied", publish(approval: asked.details["approval"]).code
  end

  test "a connection that ends before its request is approved changes nothing" do
    asked = publish
    @grant.revoke!
    sign_in_as users(:admin)
    decide(asked.details["approval"])

    assert_equal "draft", @entry.reload.status
    assert_equal [ "failed", "connection_ended" ], [ approval(asked.details["approval"]).status, approval(asked.details["approval"]).error["code"] ]
    assert Nibble::Records::Notification.exists?(user_id: users(:admin).id, kind: "apps.approval_failed")
  end

  test "narrowing the site's agent settings before approval stops the change" do
    asked = publish
    Nibble::AgentAccess.update!(areas: { "entries.articles" => { "read" => true, "write" => true, "publish" => false } })
    sign_in_as users(:admin)
    decide(asked.details["approval"])

    assert_equal "draft", @entry.reload.status
    assert_equal "forbidden", approval(asked.details["approval"]).error["code"]
    assert_equal "forbidden", publish(approval: asked.details["approval"]).code, "the app is told why, not asked again"
  end

  test "a change that no longer applies fails with its reason instead of overwriting newer work" do
    script = grant("everything", kind: "ci")
    menu = ->(title) { [ { "type" => "url", "title" => title, "url" => "/#{title.downcase}" } ] }
    run_op("update_navigation", { "handle" => "main", "lock_version" => 0, "tree" => menu.call("Start") }, grant: script)
    asked = run_op("update_navigation", { "handle" => "main", "lock_version" => 0, "tree" => menu.call("A") })
    run_op("update_navigation", { "handle" => "main", "lock_version" => 0, "tree" => menu.call("B") }, grant: script)
    sign_in_as users(:admin)
    decide(asked.details["approval"])

    assert_equal "lock_conflict", approval(asked.details["approval"]).error["code"]
    assert_equal "B", Nibble::Records::NavigationTree.find_by(handle: "main").tree.first["title"]
    get "/cp/approvals/#{asked.details['approval']}"
    props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]
    assert_equal [ "failed", "lock_conflict" ], [ props["status"], props["error"]["code"] ]
  end

  test "a connection set not to ask makes changes directly, unless the site always asks" do
    direct = grant("everything", approval_mode: "off")
    assert_equal "published", publish(grant: direct)["status"]
    assert_empty direct.approvals

    sign_in_as users(:admin)
    patch "/cp/agent-access", params: { approvals: "always" }
    other = create_entry("articles", { "title" => "Other" }, actor: users(:admin))
    assert_equal "approval_required", publish(other, grant: direct).code
    assert_equal "draft", other.reload.status
  end

  test "a waiting upload is listed by its filename, with its upload so the list can show a thumbnail" do
    Nibble::Approval.create!(grant: @grant, operation: "upload_asset", input: { "upload" => "staged-id" }, digest: "x",
      preview: { "filename" => "hero.png" })
    sign_in_as users(:admin)

    get "/cp/account/apps"
    row = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]["approvals"].sole
    assert_equal [ "hero.png", "staged-id" ], row.values_at("title", "upload")
  end

  test "people and administrators can see which apps wait for approval" do
    grant("everything", approval_mode: "off")
    sign_in_as users(:admin)

    get "/cp/account/apps"
    props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]
    assert_equal [ [ "ask", true ], [ "off", false ] ], props["apps"].map { |app| app.values_at("approval_mode", "asks_approval") }.sort
    get "/cp/agent-access"
    props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]
    assert_equal "choose", props["approvals"]
    assert_equal [ "ask", "off" ], props["grants"].map { |row| row["approval_mode"] }.sort
    assert_equal 1, props["grants"].count { |row| row["asks_approval"] }
  end

  test "an app signed in with a code always asks" do
    device = grant("everything", approval_mode: "off", via: "device")

    assert_equal "approval_required", publish(grant: device).code
  end

  test "an approval is for exactly one request, and can't be reused for another" do
    asked = publish
    sign_in_as users(:admin)
    decide(asked.details["approval"])
    other = create_entry("articles", { "title" => "Other" }, actor: users(:admin))

    assert_equal "approval_mismatch", publish(other, approval: asked.details["approval"]).code
    assert_equal "approval_mismatch", publish(approval: asked.details["approval"], grant: grant("everything")).code, "nor by another connection"
    assert_equal "draft", other.reload.status
  end

  test "the app can check an approval it asked for, and only its own" do
    asked = publish
    assert_equal "approval_pending", publish(approval: asked.details["approval"]).code

    sign_in_as users(:admin)
    decide(asked.details["approval"])
    checked = run_op("get_approval", { "approval" => asked.details["approval"] })

    assert_equal [ "done", "transition_entry", "published" ], [ checked["status"], checked["operation"], checked["result"]["status"] ]
    assert_equal "not_found", run_op("get_approval", { "approval" => asked.details["approval"] }, grant: grant("everything")).code
  end

  test "a request nobody approved in time is expired, not pending" do
    asked = publish
    approval(asked.details["approval"]).update!(expires_at: 1.minute.ago)

    assert_equal "approval_expired", publish(approval: asked.details["approval"]).code
    assert_not_equal asked.details["approval"], publish.details["approval"], "asking again starts a new request"
  end

  test "several requests are approved together under one password confirmation" do
    other = create_entry("articles", { "title" => "Other" }, actor: users(:admin))
    ids = [ publish.details["approval"], publish(other).details["approval"] ]
    theirs = Nibble::Grant.create!(user: users(:editor), oauth_client: Nibble::OauthClient.cli, kind: "app", name: "Theirs", preset: "everything",
      abilities: Nibble::AgentAccess.preset("everything"))
    foreign = Nibble::Approval.create!(grant: theirs, operation: "transition_entry", input: {}, digest: "x", preview: {})
    sign_in_as users(:admin)

    post "/cp/approvals/batch", params: { ids: ids + [ foreign.public_id ], decision: "approve" }, as: :json

    assert_equal %w[done done not_found], JSON.parse(response.body)["approvals"].map { |row| row["status"] }
    assert_equal %w[published published], [ @entry.reload.status, other.reload.status ]
    assert_equal "pending", foreign.reload.status, "someone else's request is neither seen nor decided"
  end

  test "approving several still needs a freshly confirmed password" do
    id = publish.details["approval"]
    sign_in_as users(:admin)
    Nibble::Current.session.update!(elevated_at: 1.hour.ago)

    post "/cp/approvals/batch", params: { ids: [ id ], decision: "approve" }, as: :json
    assert_response :forbidden
    assert_equal "pending", approval(id).status
  end

  test "a batch where something didn't happen is reported as a warning, not a success" do
    id = publish.details["approval"]
    sign_in_as users(:admin)

    post "/cp/approvals/batch", params: { ids: [ id, "appr_missing" ], decision: "approve" }
    assert_equal "1 done, 1 not found", flash[:alert]
    assert_nil flash[:notice]
  end

  test "only the person the app acts for can see or decide a request" do
    asked = publish
    sign_in_as users(:editor)

    get "/cp/approvals/#{asked.details['approval']}"
    assert_response :not_found
    decide(asked.details["approval"])
    assert_equal "pending", approval(asked.details["approval"]).status
  end

  test "deciding needs a freshly confirmed password" do
    asked = publish
    sign_in_as users(:admin)
    Nibble::Current.session.update!(elevated_at: 1.hour.ago)

    decide(asked.details["approval"])
    assert_equal "pending", approval(asked.details["approval"]).status
  end

  test "a change the app couldn't make anyway is refused outright, never sent for approval" do
    draft = grant("draft")

    assert_equal "forbidden", run_op("transition_entry", { "id" => @entry.id, "action" => "publish" }, grant: draft).code
    assert_empty draft.approvals
  end

  test "a dry run and a person's own script token don't wait for approval" do
    assert_equal false, publish(dry_run: true)["saved"]
    assert_equal "published", run_op("transition_entry", { "id" => @entry.id, "action" => "publish" }, grant: grant("everything", kind: "ci"))["status"]
  end

  test "the approval page shows what changes and warns about links to other sites" do
    asked = run_op("update_navigation", { "handle" => "main", "lock_version" => 0,
                                          "tree" => [ { "type" => "url", "title" => "Prize", "url" => "https://evil.example/claim" } ] })
    sign_in_as users(:admin)

    get "/cp/approvals/#{asked.details['approval']}"
    props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]
    assert_equal [ "evil.example" ], props["other_sites"]
    assert_equal "tree", props["changes"].first["field"]
  end
end
