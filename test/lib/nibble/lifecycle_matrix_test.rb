require "test_helper"

# Every action from every state, for both workflows: a wrong cell means content goes public, or stays stuck, unexpectedly.
class Nibble::LifecycleMatrixTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  ACTIONS = %w[save publish unpublish submit approve reject trash restore].freeze

  SIMPLE = {
    "draft" => %w[draft published invalid invalid invalid invalid trashed invalid],
    "scheduled" => %w[scheduled scheduled unpublished invalid invalid invalid trashed invalid],
    "published" => %w[published published unpublished invalid invalid invalid trashed invalid],
    "unpublished" => %w[unpublished published invalid invalid invalid invalid trashed invalid],
    "trashed" => %w[invalid invalid invalid invalid invalid invalid invalid draft]
  }.freeze

  REVIEW = {
    "draft" => %w[draft invalid invalid in_review invalid invalid trashed invalid],
    "in_review" => %w[in_review invalid invalid invalid approved draft trashed invalid],
    "approved" => %w[draft published invalid invalid invalid invalid trashed invalid],
    "scheduled" => %w[scheduled scheduled unpublished invalid invalid invalid trashed invalid],
    "published" => %w[published published unpublished invalid invalid invalid trashed invalid],
    "unpublished" => %w[unpublished invalid invalid in_review invalid invalid trashed invalid],
    "trashed" => %w[invalid invalid invalid invalid invalid invalid invalid draft]
  }.freeze

  { "articles" => SIMPLE, "docs" => REVIEW }.each do |collection, table|
    table.each do |state, outcomes|
      ACTIONS.zip(outcomes).each do |action, expected|
        test "#{collection}: #{action} on a #{state} entry → #{expected}" do
          entry = entry_in(collection, state)
          attrs = action == "save" ? { "title" => "Edited" } : {}
          attrs["published_at"] = 1.hour.ago.utc.iso8601 if action == "publish" && %w[draft approved unpublished].include?(state)
          result = lifecycle(entry, action, attrs)

          if expected == "invalid"
            assert result.invalid?, "expected #{action} to be refused, got #{result.status}"
          else
            assert result.ok?, "expected #{action} to succeed: #{result.errors}"
            assert_equal expected, state_of(entry.reload)
          end
        end
      end
    end
  end

  private

  def entry_in(collection, state)
    entry = create_entry(collection, { "slug" => "e-#{SecureRandom.hex(3)}" })
    case state
    when "published" then entry.update_columns(status: "published", published_at: 1.day.ago)
    when "scheduled" then entry.update_columns(status: "scheduled", published_at: 1.day.from_now)
    when "trashed" then entry.update_columns(deleted_at: Time.current)
    when "draft" then nil
    else entry.update_columns(status: state, published_at: 1.day.ago)
    end
    entry.reload
  end

  def state_of(entry) = entry.trashed? ? "trashed" : entry.status
end
