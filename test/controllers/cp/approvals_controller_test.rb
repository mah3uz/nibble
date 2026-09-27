require "test_helper"

class Nibble::Cp::ApprovalsControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup do
    Nibble::AgentAccess.update!(enabled: true, areas: { "entries.articles" => { "read" => true, "write" => true, "publish" => true },
                                                        "navigation" => { "read" => true, "write" => true } })
    @grant = grant("everything")
    @entry = create_entry("articles", { "title" => "Ready" }, actor: users(:admin))
  end

  def grant(preset, kind: "app") = Nibble::Grant.create!(user: users(:admin), oauth_client: Nibble::OauthClient.cli, kind:, name: "Claude",
    preset:, abilities: Nibble::AgentAccess.preset(preset == "draft" ? "draft" : "everything"), expires_at: 1.day.from_now)

  def run_op(name, input, grant: @grant)
    principal = Nibble::Principal.new(user: grant.user, grant:)
    Nibble::Operations.call(name, input, caller: Nibble::Operations::Caller.new(principal:, site: "https://example.com", ip: "127.0.0.1"))
  rescue Nibble::Operations::Failure => failure
    failure
  end

  def publish(entry = @entry, **extra) = run_op("transition_entry", { "id" => entry.id, "action" => "publish" }.merge(extra.stringify_keys))

  test "publishing through an app waits for its person, then happens once" do
    asked = publish
    assert_equal "approval_required", asked.code
    assert_equal "draft", @entry.reload.status, "nothing goes live until a person says so"
    assert_match "/cp/approvals/", asked.details["approval_url"]
    assert Nibble::Records::Notification.exists?(user_id: users(:admin).id, kind: "apps.approval_requested")
    assert_equal asked.details["approval"], publish.details["approval"], "asking again doesn't pile up requests"

    sign_in_as users(:admin)
    patch "/cp/approvals/#{asked.details['approval']}", params: { decision: "approve" }

    assert_equal "published", publish(approval: asked.details["approval"])["status"]
    assert_equal "approval_not_valid", publish(approval: asked.details["approval"]).code, "an approval works once"
  end

  test "an approval is for exactly one request, and can't be reused for another" do
    asked = publish
    sign_in_as users(:admin)
    patch "/cp/approvals/#{asked.details['approval']}", params: { decision: "approve" }
    other = create_entry("articles", { "title" => "Other" }, actor: users(:admin))

    assert_equal "approval_not_valid", publish(other, approval: asked.details["approval"]).code
    assert_equal "draft", other.reload.status
  end

  test "only the person the app acts for can see or decide a request" do
    asked = publish
    sign_in_as users(:editor)

    get "/cp/approvals/#{asked.details['approval']}"
    assert_response :not_found
    patch "/cp/approvals/#{asked.details['approval']}", params: { decision: "approve" }
    assert_equal "pending", Nibble::Approval.find_by(public_id: asked.details["approval"]).status
  end

  test "deciding needs a freshly confirmed password" do
    asked = publish
    sign_in_as users(:admin)
    Nibble::Current.session.update!(elevated_at: 1.hour.ago)

    patch "/cp/approvals/#{asked.details['approval']}", params: { decision: "approve" }
    assert_equal "pending", Nibble::Approval.find_by(public_id: asked.details["approval"]).status
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
