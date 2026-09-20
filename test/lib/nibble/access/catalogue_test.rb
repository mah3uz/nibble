require "test_helper"

class Nibble::Access::CatalogueTest < ActiveSupport::TestCase
  Catalogue = Nibble::Access::Catalogue

  test "every seeded role holds abilities the site actually checks, so a role can't grant fiction" do
    Role.seed_defaults!

    Role.where(superuser: false).find_each do |role|
      assert_empty Catalogue.unknown(role.abilities), "role '#{role.handle}'"
    end
  end

  test "the catalogue follows the schema, so a new collection is grantable without code" do
    values = Catalogue.abilities

    Nibble.schema.collections.each do |collection|
      assert_includes values, "entries.#{collection.handle}.publish"
      assert_includes values, "entries.#{collection.handle}.edit_own"
    end
    Nibble.schema.forms.each { |form| assert_includes values, "forms.#{form.handle}.export" }
  end

  test "renaming a collection leaves a role's ability behind, and that is reported" do
    assert_equal [ "entries.gone.view" ], Catalogue.unknown(%w[entries.posts.view entries.gone.view])
  end

  test "workflow approval is offered only where a collection runs a workflow" do
    approvals = Catalogue.abilities.grep(/\Aworkflow\.approve\./)
    expected = Nibble.schema.collections.select { |item| item["workflow"] }.map { |item| "workflow.approve.#{item.handle}" }

    assert_equal expected.sort, approvals.sort
  end

  test "form abilities are per form, so one form's submissions stay shut to another's viewer" do
    user = users(:author)
    user.roles = [ Role.create!(handle: "contact_only", title: "Contact only", abilities: %w[forms.contact.view]) ]

    assert Nibble::Access.can?(user, "forms.contact.view")
    assert_not Nibble::Access.can?(user, "forms.careers.view")
    assert_not Nibble::Access.can?(user, "forms.contact.export")
  end
end
