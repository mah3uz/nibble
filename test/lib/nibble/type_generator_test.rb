require "test_helper"

class Nibble::TypeGeneratorTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  def generated = Nibble::TypeGenerator.new.generate

  test "blueprint interfaces extend the presented record shape, so views type-check against real props" do
    assert_match "export interface PostsPost extends RecordBase {\n  collection: 'posts'", generated
    assert_match "topics: TermSummary[]", generated
  end

  test "sidecar queries become typed view props, narrowed by fields and wrapped when paginated" do
    assert_match "'posts/index': {\n    posts: Paginated<(PostsPost)>", generated
    assert_match "more: Pick<(PostsPost), 'title' | 'uri' | 'id' | 'type' | 'url'>[]", generated
    assert_match "topics: Pick<(TopicsTopic),", generated
  end
end
