require "test_helper"

class Nibble::PermissionMatrixTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  MATRIX = {
    "admin" => {
      allowed: %w[entries.posts.publish entries.posts.delete terms.topics.edit globals.site.edit navigation.main.edit
                  assets.delete forms.contact.export users.manage roles.manage api_tokens.manage webhooks.manage
                  redirects.manage trash.view utilities.view search.rebuild],
      denied: []
    },
    "editor" => {
      allowed: %w[entries.posts.publish entries.posts.delete terms.topics.edit globals.site.edit navigation.main.edit
                  assets.delete forms.contact.export redirects.manage trash.view utilities.view search.rebuild
                  workflow.approve.posts],
      denied: %w[users.manage roles.manage api_tokens.manage webhooks.manage]
    },
    "author" => {
      allowed: %w[entries.posts.view entries.posts.create entries.posts.edit_own terms.topics.view assets.view assets.upload],
      denied: %w[entries.posts.publish entries.posts.delete assets.delete forms.contact.view globals.site.edit
                 navigation.main.edit users.manage trash.view utilities.view]
    },
    "contributor" => {
      allowed: %w[entries.posts.view entries.posts.create entries.posts.edit_own terms.topics.view assets.view],
      denied: %w[assets.upload entries.posts.publish entries.posts.delete forms.contact.view users.manage]
    },
    "viewer" => {
      allowed: %w[entries.posts.view terms.topics.view assets.view],
      denied: %w[entries.posts.create entries.posts.edit_own entries.posts.publish assets.upload forms.contact.view
                 globals.site.edit users.manage trash.view]
    }
  }.freeze

  setup { Role.seed_defaults! }

  def holder(handle)
    users(:author).tap { |user| user.roles = [ Role.find_by!(handle:) ] }.reload
  end

  MATRIX.each do |handle, expectations|
    test "the seeded #{handle} role grants exactly what it's meant to" do
      user = holder(handle)

      expectations[:allowed].each { |ability| assert Nibble::Access.can?(user, ability), "#{handle} should have #{ability}" }
      expectations[:denied].each { |ability| assert_not Nibble::Access.can?(user, ability), "#{handle} shouldn't have #{ability}" }
    end
  end

  test "own-record abilities need the record, so a blanket grant can't leak through" do
    author = holder("author")
    mine = create_entry("articles", { "title" => "Mine" }, actor: author)
    theirs = create_entry("articles", { "title" => "Theirs" }, actor: users(:editor))

    assert Nibble::Access.can?(author, "entries.articles.edit", mine)
    assert_not Nibble::Access.can?(author, "entries.articles.edit", theirs)
    assert_not Nibble::Access.can?(author, "entries.articles.edit"), "no record means no ownership to lean on"
  end

  test "the sidebar a role sees matches what it may do" do
    sections = ->(handle) { Nibble::Cp::Navigation.for(holder(handle)).flat_map { |section| section["items"] }.map { |item| item["title"] } }

    assert_includes sections.call("admin"), "Users"
    assert_includes sections.call("admin"), "API tokens"
    assert_not_includes sections.call("editor"), "Users"
    assert_not_includes sections.call("editor"), "Roles"
    assert_includes sections.call("editor"), "Forms"
    assert_not_includes sections.call("author"), "Forms"
    assert_not_includes sections.call("viewer"), "Trash"
  end

  test "a signed-out visitor has nothing, whatever the ability" do
    Nibble::Access::Catalogue.abilities.each do |ability|
      assert_not Nibble::Access.can?(nil, ability)
    end
  end

  test "a superuser role is never narrowed by the catalogue" do
    admin = holder("admin")

    Nibble::Access::Catalogue.abilities.each { |ability| assert Nibble::Access.can?(admin, ability) }
    assert Nibble::Access.can?(admin, "something.invented.later")
  end

  test "API token scopes are separate from a person's abilities" do
    _, read = ApiToken.issue(name: "Read", scopes: %w[read])
    _, preview = ApiToken.issue(name: "Preview", scopes: %w[preview])
    _, manager = ApiToken.issue(name: "Manager", scopes: %w[read manage:posts])

    assert ApiToken.authenticate(read).allows?("read")
    assert_not ApiToken.authenticate(read).allows?("preview")
    assert ApiToken.authenticate(preview).allows?("read")
    assert ApiToken.authenticate(manager).manages?("posts")
    assert_not ApiToken.authenticate(manager).manages?("pages")
    assert_not ApiToken.authenticate(read).manages?("posts")
  end
end
