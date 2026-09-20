require "test_helper"

class Admin::CommentsTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup { sign_in_as users(:editor) }

  def json = JSON.parse(response.body)

  test "an editorial note threads under its parent and stays on the record" do
    entry = create_entry("articles", { "title" => "Needs a note" })
    path = "/admin/collections/articles/entries/#{entry.id}/comments"

    post path, params: { comment: { body: "This intro reads long." } }
    assert_response :created
    root = json["comments"].first

    post path, params: { comment: { body: "Trimmed it.", parent_id: root["id"] } }
    get path

    assert_equal 1, json["comments"].size, "a reply belongs under its parent, not beside it"
    assert_equal [ "Trimmed it." ], json["comments"].first["replies"].map { |reply| reply["body"] }
  end

  test "a mention tells the person they were mentioned, and the mentioner hears nothing" do
    entry = create_entry("articles", { "title" => "Mention me" })

    post "/admin/collections/articles/entries/#{entry.id}/comments",
         params: { comment: { body: "@author@example.com can you take this?" } }

    notification = Nibble::Records::Notification.find_by(user_id: users(:author).id)
    assert_equal "comment.mentioned", notification&.kind, "a mention nobody is told about is just text"
    assert_equal "Mention me", notification.data["title"]
    assert_nil Nibble::Records::Notification.find_by(user_id: users(:editor).id), "you don't get told about your own note"
  end

  test "only the author of a note can remove it" do
    entry = create_entry("articles", { "title" => "Whose note" })
    comment = Nibble::Records::Comment.create!(subject_type: "Nibble::Records::Entry", subject_id: entry.id,
                                               author_id: users(:author).id, body: "Not yours")

    delete "/admin/collections/articles/entries/#{entry.id}/comments/#{comment.id}"

    assert_response :forbidden
    assert Nibble::Records::Comment.exists?(comment.id)
  end
end
