require "test_helper"

class Admin::NibbleApi::RelationshipsControllerTest < ActionDispatch::IntegrationTest
  class FakeResolver
    attr_reader :last_call

    def search(query:, scope:, limit:)
      @last_call = { query:, scope:, limit: }
      [ { "id" => "1", "title" => "About" } ]
    end
  end

  setup do
    @resolver = FakeResolver.new
    Nibble::Resolvers.register("entry", @resolver)
  end

  teardown { Nibble.boot! }

  test "pickers search through the registered resolver with the field's scope and a capped limit" do
    sign_in_as users(:editor)
    get admin_nibble_relationships_path("entry"), params: { q: " abo ", scope: { collections: [ "pages" ] }, limit: 500 }, as: :json

    assert_response :success
    assert_equal [ { "id" => "1", "title" => "About" } ], JSON.parse(response.body)["data"]
    assert_equal({ query: "abo", scope: { "collections" => [ "pages" ] }, limit: 50 }, @resolver.last_call)
  end

  test "an unknown record type is a 404, not a server error" do
    sign_in_as users(:editor)
    get admin_nibble_relationships_path("gadget"), as: :json
    assert_response :not_found
  end

  test "signed-out visitors can't search content" do
    get admin_nibble_relationships_path("entry"), as: :json
    assert_not_equal 200, response.status
    assert_nil @resolver.last_call
  end
end
