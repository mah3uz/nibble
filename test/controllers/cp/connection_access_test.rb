require "test_helper"

class Nibble::Cp::ConnectionAccessTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup do
    Nibble::AgentAccess.update!(enabled: true, areas: { "entries.articles" => { "read" => true, "write" => true, "publish" => true },
                                                        "assets" => { "read" => true, "write" => false } })
    roles(:author).update!(abilities: roles(:author).abilities + %w[apps.connect])
    @grant = connect(users(:author), "read")
  end

  def connect(user, preset, **extra) = Nibble::Grant.create!(user:, oauth_client: Nibble::OauthClient.cli, kind: "app", name: "Claude",
    preset:, abilities: Nibble::AgentAccess.preset(preset), via: "browser", **extra)

  def props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]

  def change_own(grant = @grant, **attrs) = patch("/cp/account/apps/#{grant.id}", params: attrs)

  def change_any(grant = @grant, **attrs) = patch("/cp/agent-access/grants/#{grant.id}", params: attrs)

  def notified?(user = users(:author)) = Nibble::Records::Notification.exists?(user_id: user.id, kind: "apps.access_changed")

  test "a person widens their own connection only with a freshly confirmed password" do
    sign_in_as users(:author)
    Nibble::Current.session.update!(elevated_at: 20.minutes.ago)
    change_own(preset: "draft")
    assert_equal "read", @grant.reload.preset, "a stolen session alone can't hand an app more"

    Nibble::Current.session.update!(elevated_at: Time.current)
    change_own(preset: "draft")
    assert_equal [ "draft", Nibble::AgentAccess.preset("draft") ], [ @grant.reload.preset, @grant.abilities ]
    assert_not notified?, "nobody needs telling about their own change"
    assert Nibble::Records::AuditEntry.exists?(action: "auth.app_access_changed", actor_id: users(:author).id, subject_id: @grant.id)
  end

  test "an administrator can widen anyone's connection, but never past its owner's role or the site's settings" do
    sign_in_as users(:admin)

    change_any(preset: "custom", areas: { "entries.articles" => %w[read write publish] })
    assert_equal "read", @grant.reload.preset, "the author can't publish, so neither can the app, whoever edits it"

    change_any(preset: "custom", areas: { "assets" => %w[read write] })
    assert_equal "read", @grant.reload.preset, "the site doesn't let apps write assets"

    change_any(preset: "custom", areas: { "entries.articles" => %w[read write] }, approval_mode: "off")
    assert_equal [ "custom", "off" ], [ @grant.reload.preset, @grant.approval_mode ]
    assert @grant.covers?("entries.articles.create")
    assert_not @grant.covers?("entries.articles.publish")
  end

  test "an administrator's change needs a freshly confirmed password too" do
    sign_in_as users(:admin)
    Nibble::Current.session.update!(elevated_at: 20.minutes.ago)
    change_any(preset: "draft")

    assert_equal "read", @grant.reload.preset
  end

  test "nobody else can change a person's connection without managing agent access" do
    roles(:editor).update!(abilities: roles(:editor).abilities + %w[apps.connect])
    sign_in_as users(:editor)

    change_own(preset: "draft")
    assert_response :not_found
    change_any(preset: "draft")
    assert_response :forbidden
    assert_equal "read", @grant.reload.preset
  end

  test "a code sign-in or a script token never gets everything, and a code sign-in always asks" do
    sign_in_as users(:admin)
    device = connect(users(:admin), "draft", via: "device")
    script = Nibble::Grant.create!(user: users(:admin), kind: "ci", name: "Script", preset: "read", abilities: Nibble::AgentAccess.preset("read"),
      via: "token")

    change_own(device, preset: "everything")
    change_own(script, preset: "everything")
    assert_equal [ "draft", "read" ], [ device.reload.preset, script.reload.preset ]

    change_own(device, approval_mode: "off")
    assert_equal "ask", device.reload.approval_mode

    browser = connect(users(:admin), "read")
    change_own(browser, preset: "everything", approval_mode: "off")
    assert_equal [ "everything", "off" ], [ browser.reload.preset, browser.approval_mode ], "the same change is fine for an app signed in in a browser"
  end

  test "an administrator's change tells the owner what changed and who changed it, and is audited" do
    sign_in_as users(:admin)
    change_any(preset: "draft", approval_mode: "off")

    notice = Nibble::Records::Notification.find_by!(user_id: users(:author).id, kind: "apps.access_changed")
    assert_equal "Claude", notice.data["title"]
    assert_equal "Admin User changed access Read → Draft and approvals Ask before live changes → Make changes without asking.", notice.data["comment"]
    entry = Nibble::Records::AuditEntry.find_by!(action: "auth.app_access_changed", subject_id: @grant.id)
    assert_equal [ users(:admin).id, users(:author).id ], [ entry.actor_id, entry.changeset["owner"] ]
    assert_equal [ "read", "draft" ], entry.changeset["preset"]
  end

  test "saving what is already there records and notifies nothing" do
    sign_in_as users(:admin)

    assert_no_difference -> { Nibble::Records::AuditEntry.where(action: "auth.app_access_changed").count } do
      change_any(preset: "read")
    end
    assert_not notified?
  end

  test "a narrowed connection is refused the removed operation on its very next request" do
    @grant.update!(preset: "draft", abilities: Nibble::AgentAccess.preset("draft"))
    token = Nibble::OauthToken.issue(@grant, "access", resource: "https://example.com/api/v1")
    headers = { "Authorization" => "Bearer #{token}" }
    post "/api/v1/operations/create_entry", params: { collection: "articles", data: { title: "Before" } }, headers:, as: :json
    assert_response :success

    sign_in_as users(:author)
    change_own(preset: "read")

    post "/api/v1/operations/create_entry", params: { collection: "articles", data: { title: "After" } }, headers:, as: :json
    assert_response :forbidden
    assert_match "Collections: Write", JSON.parse(response.body)["detail"]
  end

  test "each connection carries its current access and the choices its owner could give it" do
    device = connect(users(:admin), "draft", via: "device")
    sign_in_as users(:admin)

    get "/cp/account/apps"
    row = props["apps"].find { |app| app["id"] == device.id }
    assert_equal [ "draft", "ask", true, "device" ], row.values_at("preset", "approval_mode", "asks_approval", "via")
    assert_equal %w[read write], row["areas"]["entries.articles"]
    assert_not row["options"]["presets"].find { |preset| preset["value"] == "everything" }["available"]
    assert_not row["options"]["approvals_choosable"]

    get "/cp/agent-access"
    row = props["grants"].find { |grant| grant["id"] == @grant.id }
    assert_equal [ "Author User", "author@example.com" ], row["owner"].values_at("name", "email")
    assert_equal({ "entries.articles" => %w[read], "assets" => %w[read] }, row["areas"].slice("entries.articles", "assets"))
    articles = row["options"]["areas"].find { |area| area["key"] == "entries.articles" }
    assert_equal [ true, true, false ], articles["columns"].first(3).map { |column| column["available"] },
      "the choices are the owner's, not the administrator's: the author can't publish"
  end
end
